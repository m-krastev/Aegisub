local tr = aegisub.gettext

script_name = tr"Apply Minimum Gap"
script_description = tr"Apply a minimum gap between subtitles based on video framerate."
script_author = "Matey Krastev"
script_version = "0.0.1"

function apply_minimum_gap(subs, sel)
    local ms_per_frame = aegisub.ms_from_frame(2) - aegisub.ms_from_frame(1) -- Get video framerate
    local default_gap = 2 -- Default to 50ms if no video

    button, result_table = aegisub.dialog.display({
        {class="label", label=tr"Minimum Frame Gap:", width=2, height=1, x = 0, y = 0},
        min_gap={class="intedit", name="min_gap", value=default_gap, min=0, max=1000, x=2, y = 0},
        -- Also display a label with the video framerate
        {class="label", label=tr"Relative duration of a frame (ms): " .. ms_per_frame, width=2, height=1, x = 0, y = 1},
    })

    if not button then
        return
    end

    local min_gap = result_table.min_gap

    -- Apply minimum gap between selected lines
    if #sel > 1 then
        table.sort(sel, function(a, b) return subs[a].start_time < subs[b].start_time end)

        -- Iterate through the selected lines and apply the minimum gap of frames
        for i = 1, #sel - 1 do
            local line_index = sel[i]
            local next_line_index = sel[i + 1]
            local line = subs[line_index]
            local next_line = subs[next_line_index]

            local line_end_frame = aegisub.frame_from_ms(line.end_time)
            local next_line_start_frame = aegisub.frame_from_ms(next_line.start_time)
            local gap = next_line_start_frame - line_end_frame

            if gap < min_gap then
                local new_end_time = aegisub.ms_from_frame(next_line_start_frame - min_gap)
                line.end_time = new_end_time
                subs[line_index] = line -- Update the subs table with the modified line
            end
        end

    end

    aegisub.set_undo_point(script_name)
end

aegisub.register_macro(script_name, script_description, apply_minimum_gap)