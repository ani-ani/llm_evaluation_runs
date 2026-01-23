module total_match(
    input        [7:0] list1_valid,
    input        [7:0][7:0][7:0] list1_data,
    input        [7:0][3:0] list1_lengths,
    input        [7:0] list2_valid,
    input        [7:0][7:0][7:0] list2_data,
    input        [7:0][3:0] list2_lengths,
    output logic [7:0] result_list1_valid,
    output logic [7:0][7:0][7:0] result_list1_data,
    output logic [7:0][3:0] result_list1_lengths,
    output logic is_first_list
);

    // Internal signals for total character counts
    logic [6:0] sum_list1;
    logic [6:0] sum_list2;

    // Compute total characters for list1
    always_comb begin
        sum_list1 = 0;
        for (int i = 0; i < 8; i++) begin
            if (list1_valid[i]) begin
                sum_list1 = sum_list1 + list1_lengths[i];
            end
        end
    end

    // Compute total characters for list2
    always_comb begin
        sum_list2 = 0;
        for (int i = 0; i < 8; i++) begin
            if (list2_valid[i]) begin
                sum_list2 = sum_list2 + list2_lengths[i];
            end
        end
    end

    // Determine which list to output and route the signals
    always_comb begin
        if (sum_list1 <= sum_list2) begin
            // Output list1
            result_list1_valid = list1_valid;
            result_list1_data = list1_data;
            result_list1_lengths = list1_lengths;
            is_first_list = 1'b1;
        end else begin
            // Output list2
            result_list1_valid = list2_valid;
            result_list1_data = list2_data;
            result_list1_lengths = list2_lengths;
            is_first_list = 1'b0;
        end
    end

endmodule