--[[
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of
the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.
]]

script_name = "Пренасяне"
script_description = "Разделя дълги реплики на редове."
script_author = "ShadeSeeker"
script_version = "0.0.2"

local default_max_row = 38
local default_max_processable = 74

local unicode = require('aegisub.unicode')
local re = require('aegisub.re')
local util = require('aegisub.util')

local function ms_to_time_string(total_ms)
    local centis_part = math.floor(total_ms % 1000 / 100)
    local total_s = math.floor(total_ms / 1000)
    
    local s_part = total_s % 60
    local total_m = math.floor(total_s / 60)
    
    local m_part = total_m % 60
    local h_part = math.floor(total_m / 60)
    
    return string.format("%d:%.2d:%.2d.%.2d", h_part, m_part, s_part, centis_part)
end

local space_and_punct_regex = re.compile("[[:P*:][:space:]]")
local block_regex = re.compile("\\{[^\\}]*\\}")

local function count_important_chars(s)
    local block_stripped = block_regex:sub(s, "")
    local important_chars_only = space_and_punct_regex:sub(block_stripped, "")
    return unicode.len(important_chars_only)
end

local break_hint_punct = re.compile("(?:[,\\.\\?!]|\\?!)$")

-- return bool, error_string
local function should_break_before(total_len, first_row, first_row_len, mid_word, mid_word_len, max_row)
    local long_first_row_len = first_row_len + mid_word_len
    
    -- prefer to break at punctuation
    local before_ends_in_punct = break_hint_punct:match(first_row) ~= nil
    local mid_ends_in_punct = break_hint_punct:match(mid_word) ~= nil
    
    if before_ends_in_punct and first_row_len <= max_row and total_len - first_row_len <= max_row then
        return true, nil
    elseif mid_ends_in_punct and long_first_row_len <= max_row and total_len - long_first_row_len <= max_row then
        return false, nil
    end
    
    -- prefer the word break closer to the middle
    local early_break_to_middle = (total_len / 2) - first_row_len
    local late_break_to_middle = long_first_row_len - (total_len / 2)
    
    if early_break_to_middle <= late_break_to_middle and first_row_len <= max_row and total_len - first_row_len <= max_row then
        return true, nil
    elseif early_break_to_middle > late_break_to_middle and long_first_row_len <= max_row and total_len - long_first_row_len <= max_row then
        return false, nil
    end
    
    return nil, "не може да бъде пренесена спазвайки максималния брой букви на ред"
end

function add_line_breaks(subs, sel)
    button, result_table = aegisub.dialog.display({
        {x=0, y=0, width=2, height=1, class="label", label="Максимално брой букви на ред:" },
        {x=2, y=0, width=2, height=1, class="intedit", name="max_row", value=default_max_row, min=5, max=100 },
        {x=0, y=2, width=2, height=1, class="label", label="Максимална обработваема дължина:" },
        {x=2, y=2, width=2, height=1, class="intedit", name="max_processable", value=default_max_processable, min=5, max=500 },
    })

    if not button then
        return
    end

    -- Check if values are nil, and if so, use the default value
    local max_row = result_table.max_row or default_max_row
    local max_processable = result_table.max_processable or default_max_processable
    
    if math.ceil(max_processable / 2) > max_row  then
        aegisub.log(1, "Половината на максимална обработваемата дължина " .. default_max_processable .. " е повече от максималния брой букви на ред " .. max_row .. "\n")
        return
    end

    local lines_changed = 0
    local lines_not_adjusted = 0
    
    for _, current_index in ipairs(sel) do
    
        local line = subs[current_index]
        
        local text = line.text
        
        if line.class == "dialogue" and not line.comment and not string.find(text, "\\N", 1, true) and not string.find(text, "\\n", 1, true) then
            
            local line_len = count_important_chars(text)
            
            if max_row < line_len and line_len <= max_processable then
                
                local line_problem_message = nil
                local half_length = line_len / 2
                local first_row = ""
                local second_row = ""
                local is_in_first_row = true
                local current_length = 0
                
                for word in util.words(text) do
                    local next_in_second_row = false
                    if is_in_first_row then
                        local word_length = count_important_chars(word)
                        
                        if current_length + word_length >= half_length then
                            
                            local break_before
                            break_before, line_problem_message = should_break_before(line_len, first_row, current_length, word, word_length, max_row)
                            if line_problem_message ~= nil then
                                break
                            end
                            if break_before then
                                is_in_first_row = false
                            else
                                next_in_second_row = true
                            end
                        end
                        
                        current_length = current_length + word_length
                    end
                    
                    if is_in_first_row then
                        if #first_row == 0 then
                            first_row = word
                        else
                            first_row = first_row .. " " .. word
                        end
                    else
                        if #second_row == 0 then
                            second_row = word
                        else
                            second_row = second_row .. " " .. word
                        end
                    end
                    
                    if next_in_second_row then
                        is_in_first_row = false
                    end
                end
                
                if line_problem_message ~= nil then                
                    if lines_not_adjusted == 0 then
                        aegisub.log(2, "Следните редове не могат да бъдат коригирани автоматично:\n")
                    end
                    aegisub.log(2, "- ред започващ на " .. ms_to_time_string(line.start_time) .. ": " .. line_problem_message .. "\n")
                    lines_not_adjusted = lines_not_adjusted + 1
                else
                    text = first_row .. "\\N " .. second_row
                end
            elseif line_len > max_processable then
                if lines_not_adjusted == 0 then
                    aegisub.log(2, "Следните редове не могат да бъдат коригирани автоматично:\n")
                end
                aegisub.log(2, "- ред започващ на " .. ms_to_time_string(line.start_time) .. ": надвишава максималната обработваема дължина\n")
                lines_not_adjusted = lines_not_adjusted + 1
            end
            
            -- If we changed the line, write back the change
            if line.text ~= text then
                line.text = text
                subs[current_index] = line
                lines_changed = lines_changed + 1
            end
        end
    end
    if lines_not_adjusted > 0 then
        aegisub.log(2, "Брой непроменени редове извън рамките: " .. lines_not_adjusted .. "\n")
    end
    aegisub.log(3, "Брой променени редове: " .. lines_changed .. "\n")
    aegisub.set_undo_point(script_name)
end

aegisub.register_macro(script_name, script_description, add_line_breaks)
