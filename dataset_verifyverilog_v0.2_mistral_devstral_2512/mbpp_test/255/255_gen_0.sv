module combinations_with_replacement (
    input [2:0] num_elements,
    input [2:0] combo_length,
    input [3:0][7:0] elements,
    output reg [15:0] num_combos,
    output reg [9:0][3:0][7:0] combos
);

    integer i, j, k, l, idx;
    reg [1:0] indices [0:3];

    always @* begin
        num_combos = 0;
        for (i = 0; i < 10; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                combos[i][j] = 8'h00;
            end
        end

        case (combo_length)
            1'd1: begin
                num_combos = num_elements;
                for (i = 0; i < num_elements; i = i + 1) begin
                    combos[i][0] = elements[i];
                end
            end
            2'd2: begin
                idx = 0;
                for (i = 0; i < num_elements; i = i + 1) begin
                    for (j = i; j < num_elements; j = j + 1) begin
                        combos[idx][0] = elements[i];
                        combos[idx][1] = elements[j];
                        idx = idx + 1;
                    end
                end
                num_combos = idx;
            end
            3'd3: begin
                idx = 0;
                for (i = 0; i < num_elements; i = i + 1) begin
                    for (j = i; j < num_elements; j = j + 1) begin
                        for (k = j; k < num_elements; k = k + 1) begin
                            combos[idx][0] = elements[i];
                            combos[idx][1] = elements[j];
                            combos[idx][2] = elements[k];
                            idx = idx + 1;
                        end
                    end
                end
                num_combos = idx;
            end
            4'd4: begin
                idx = 0;
                for (i = 0; i < num_elements; i = i + 1) begin
                    for (j = i; j < num_elements; j = j + 1) begin
                        for (k = j; k < num_elements; k = k + 1) begin
                            for (l = k; l < num_elements; l = l + 1) begin
                                combos[idx][0] = elements[i];
                                combos[idx][1] = elements[j];
                                combos[idx][2] = elements[k];
                                combos[idx][3] = elements[l];
                                idx = idx + 1;
                            end
                        end
                    end
                end
                num_combos = idx;
            end
            default: begin
                num_combos = 0;
            end
        endcase
    end

endmodule