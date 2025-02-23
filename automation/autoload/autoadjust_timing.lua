local tr = aegisub.gettext

script_name = tr"Autoadjust Timing"
script_description = tr"Smartly extend the start and end times of selected lines to fit within the video margins."
script_author = "Matey Krastev"
script_version = "0.0.1"

function autoadjust_timing_smart(subs, sel)
    button, result_table = aegisub.dialog.display({
        {class="label", label=tr"Minimum Duration (ms):", width=2, height=1, x = 0, y = 0},
        min_duration={class="intedit", name="min_duration", value=3000, min=100, max=10000, x=2, y = 0},
        {class="label", label=tr"Minimum Distance (ms):", width=2, height=1, x = 0, y = 1},
        min_distance={class="intedit", name="min_distance", value=50, min=0, max=1000, width=2, height=1, x=2, y = 1},
        {class="label", label=tr"Maximum Duration (ms):", width=2, height=1, x = 0, y = 2},
        max_duration={class="intedit", name="max_duration", value=10000, min=1000, max=60000, width=2, height=1, x=2, y = 2},
    })

    if not button then
        return
    end

    local min_duration = result_table.min_duration
    local min_distance = result_table.min_distance
    local max_duration = result_table.max_duration

    -- Check if values are nil, and if so, use the default value
    if not min_duration then
        min_duration = 3000
    end
    if not min_distance then
        min_distance = 50
    end
    if not max_duration then
        max_duration = 10000
    end

    for _, i in ipairs(sel) do
        local line = subs[i]
        aegisub.debug.out("start_time: " .. line.start_time .. ", end_time: " .. line.end_time .. ", min_duration: " .. min_duration .. ", min_distance: " .. min_distance .. ", max_duration: " .. max_duration .. "\n")

        if line.class == "dialogue" and not line.comment then
            local duration = line.end_time - line.start_time

            -- Enforce maximum duration
            if duration > max_duration then
                line.end_time = line.start_time + max_duration
                duration = max_duration -- Update duration to the new value
            end

            if duration < min_duration then
                -- Find the next dialogue line
                -- Might need to change this so that it might find a line that's not overlapping
                local next_line_index = nil
                for j = i + 1, #sel do
                    if subs[j].class == "dialogue" and not subs[j].comment then
                        next_line_index = j
                        break
                    end
                end

                if next_line_index then
                    local next_line = subs[next_line_index]
                    local new_end_time = next_line.start_time - min_distance -- Apply minimum distance
                    if new_end_time > line.start_time + min_duration then
                        line.end_time = new_end_time
                    else
                        line.end_time = line.start_time + min_duration
                    end
                    -- Enforce maximum duration after extension
                    if line.end_time > line.start_time + max_duration then
                        line.end_time = line.start_time + max_duration
                    end
                    subs[i] = line
                else
                    -- If there is no next line, extend it by the min duration
                    line.end_time = line.start_time + min_duration
                    -- Enforce maximum duration after extension
                    if line.end_time > line.start_time + max_duration then
                        line.end_time = line.start_time + max_duration
                    end
                    subs[i] = line
                end
            end
        end
    end
    aegisub.set_undo_point(script_name)
end

aegisub.register_macro(script_name, script_description, autoadjust_timing_smart)