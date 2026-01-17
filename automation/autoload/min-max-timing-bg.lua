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

script_name = "Вкарай таймингите в рамки"
script_description = "Налага мин. и макс. време на избраните репликите, и мин. отстояние между тях."
script_author = "ShadeSeeker, Matey Krastev"
script_version = "0.1.4"

local default_min_duration = 160
local default_max_duration = 650
local default_min_distance = 2

function ms_to_time_string(total_ms)
    local centis_part = math.floor(total_ms % 1000 / 10)
    local total_s = math.floor(total_ms / 1000)
    
    local s_part = total_s % 60
    local total_m = math.floor(total_s / 60)
    
    local m_part = total_m % 60
    local h_part = math.floor(total_m / 60)
    
    return string.format("%d:%.2d:%.2d.%.2d", h_part, m_part, s_part, centis_part)
end

function autoadjust_timing_smart(subs, sel)
    button, result_table = aegisub.dialog.display({
        {x=0, y=0, width=2, height=1, class="label", label="Минимално време (стотни):" },
        {x=2, y=0, width=2, height=1, class="intedit", name="min_duration", value=default_min_duration, min=10, max=1000 },
        {x=0, y=2, width=2, height=1, class="label", label="Максимално време (стотни):" },
        {x=2, y=2, width=2, height=1, class="intedit", name="max_duration", value=default_max_duration, min=100, max=6000 },
        {x=0, y=1, width=2, height=1, class="label", label="Мин. време между репликите (стотни):" },
        {x=2, y=1, width=2, height=1, class="intedit", name="min_distance", value=default_min_distance, min=0, max=100 },
    })

    if not button then
        return
    end

    -- Check if values are nil, and if so, use the default value
    local min_duration = (result_table.min_duration or default_min_duration) * 10
    local max_duration = (result_table.max_duration or default_max_duration) * 10
    local min_distance = (result_table.min_distance or default_min_distance) * 10
    
    --aegisub.log(3, "Минималното време " .. min_duration .. "ms, максималното време " .. max_duration .. "ms, мин. време между репликите " .. min_distance .. "ms\n")

    if min_duration > max_duration then
        aegisub.log(1, "Минималното време " .. min_duration .. "ms е повече от максималното време " .. max_duration .. "ms\n")
        return
    end

    local lines_changed = 0
    local lines_not_adjusted = 0

    for i = 1, #sel do
        local current_index = sel[i]
        local line = subs[current_index]
        
        aegisub.log(4, "Processing line " .. current_index .. " starting on " .. ms_to_time_string(line.start_time) .. " ending on " .. ms_to_time_string(line.end_time) .. "\n")

        if line.class == "dialogue" and not line.comment then
        
            -- walk back from current line to find previous dialogue line
            local earliest_start = 0
            for prev_line_index = current_index - 1, 1, -1 do
                local prev_line = subs[prev_line_index]
                if prev_line.class == "dialogue" and not prev_line.comment then
                    aegisub.log(4, "  prev_line.end_time: " .. ms_to_time_string(prev_line.end_time) .. "\n")
                    earliest_start = prev_line.end_time + min_distance
                    break
                end
            end
            aegisub.log(4, "  earliest_start: " .. ms_to_time_string(earliest_start) .. "\n")
            
            -- walk forward from current line to find next dialogue line
            local latest_end = nil
            for next_line_index = current_index + 1, #subs do
                local next_line = subs[next_line_index]
                if next_line.class == "dialogue" and not next_line.comment then
                    aegisub.log(4, "  next_line.start_time: " .. ms_to_time_string(next_line.start_time) .. "\n")
                    latest_end = next_line.start_time - min_distance
                    break
                end
            end
            aegisub.log(4, "  latest_end: " .. ms_to_time_string(latest_end) .. "\n")
        
            local duration = line.end_time - line.start_time
            local original_start_time = line.start_time
            local original_end_time = line.end_time
            aegisub.log(4, "  original duration: " .. duration .. "ms\n")

            -- Apply maximum duration
            if duration > max_duration then
                line.end_time = line.start_time + max_duration
                duration = max_duration
                aegisub.log(4, "  reducing duration to max: " .. duration .. "ms\n")
            end
            
            local space_before = math.max(line.start_time - earliest_start, 0)
            aegisub.log(4, "  space_before: " .. space_before .. "ms\n")
            local space_after = 0
            if latest_end ~= nil then
                space_after = latest_end - line.end_time
            end
            aegisub.log(4, "  space_after: " .. space_after .. "ms\n")
            local extension_length = min_duration - duration
            aegisub.log(4, "  extension_length: " .. extension_length .. "ms\n")
            
            if (extension_length > 0 and extension_length > space_before + space_after) or (space_after < 0 and space_before < -space_after) then
                if lines_not_adjusted == 0 then
                    aegisub.log(2, "Следните редове не могат да бъдат коригирани автоматично така че да изпълняват зададените рамки:\n")
                end
                aegisub.log(2, "- ред започващ на " .. ms_to_time_string(original_start_time) .. "\n")
                lines_not_adjusted = lines_not_adjusted + 1
                
                -- revert any changes
                line.start_time = original_start_time
                line.end_time = original_end_time
            else
            
                -- shift away from next line
                if space_after < 0 then
                    line.start_time = line.start_time + space_after
                    line.end_time = line.end_time + space_after
                    space_before = space_before + space_after
                    
                    aegisub.log(4, "  shifting away from next line by space_after(" .. space_after .. "ms)\n")
                    aegisub.log(4, "    line.start_time: " .. ms_to_time_string(line.start_time) .. "\n")
                    aegisub.log(4, "    line.end_time: " .. ms_to_time_string(line.end_time) .. "\n")
                    aegisub.log(4, "    space_before left: " .. space_before .. "ms\n")
                    
                    space_after = 0
                end
            
                -- expansion needed
                if extension_length > 0 then
                    aegisub.log(4, "  extending by extension_length(" .. extension_length .. "ms)\n")
                    -- put up to half the extension (rounded up) at the end
                    local later_half = math.ceil(extension_length / 20) * 10 -- we can't work with units smaller than 10ms
                    local extend_start = 0
                    local extend_end = 0
                    if space_after < later_half then
                        -- if we can't put full half at end, put as much as possible and the rest at the start
                        extend_end = space_after
                        extend_start = extension_length - space_after
                    else
                        -- if end fits at least half, maybe start doesn't
                        -- so put as much as possible of the other half in front and the rest in the end
                        extend_start = math.min(extension_length - later_half, space_before)
                        extend_end = extension_length - extend_start
                    end
                    
                    line.start_time = line.start_time - extend_start
                    line.end_time = line.end_time + extend_end
                    
                    aegisub.log(4, "    extend_start: " .. extend_start .. "ms\n")
                    aegisub.log(4, "    line.start_time: " .. ms_to_time_string(line.start_time) .. "\n")
                    aegisub.log(4, "    extend_end: " .. extend_end .. "ms\n")
                    aegisub.log(4, "    line.end_time: " .. ms_to_time_string(line.end_time) .. "\n")
                end
            end
            
            -- if we changed the times, write back the change
            if original_end_time ~= line.end_time or original_start_time ~= line.start_time then
                subs[current_index] = line
                lines_changed = lines_changed + 1
            end
        end
    end
    if lines_not_adjusted > 0 then
        --aegisub.log(2, "Брой непроменени редове извън рамките: " .. lines_not_adjusted .. "\n")
    end
    aegisub.log(3, "Брой променени редове: " .. lines_changed .. "\n")
    aegisub.set_undo_point(script_name)
end

aegisub.register_macro(script_name, script_description, autoadjust_timing_smart)
