module list_filter (
        input [3:0] main_list [0:7],
        input [3:0] filter_list [0:7],
        input [2:0] main_len,
        input [2:0] filter_len,
        output [3:0] result [0:7],
        output [2:0] result_len
   );

   always_comb begin
        // Initialize the result array to zeros and result_len to 0
        for (int i = 0; i < 8; i++) begin
            result[i] = 4'b0;
        end
        result_len = 3'b0;

        // For each element in the main list (only up to main_len)
        for (int i = 0; i < 8; i++) begin
            if (i < main_len) begin
                bit [3:0] current_main = main_list[i];
                bit found = 1'b0;

                // Check against every element in the filter list (up to filter_len)
                for (int j = 0; j < 8; j++) begin
                    if (j < filter_len) begin
                        if (current_main == filter_list[j]) begin
                            found = 1'b1;
                        end
                    end
                end

                // If the element is not found in the filter list, add it to the result
                if (!found) begin
                    result[result_len] = current_main;
                    result_len = result_len + 1;
                end
            end
        end
   end

   endmodule