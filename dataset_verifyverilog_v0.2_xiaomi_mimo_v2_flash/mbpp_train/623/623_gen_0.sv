module nth_power_array (
    input [7:0][15:0] nums_i,
    input [2:0] power_i,
    output logic [7:0][31:0] results_o
);

    // Intermediate power values for each input element
    logic [7:0][31:0] p1;
    logic [7:0][31:0] p2;
    logic [7:0][31:0] p3;
    logic [7:0][31:0] p4;
    logic [7:0][31:0] p5;

    // Loop variable for generate block
    genvar i;

    generate
        for (i = 0; i < 8; i = i + 1) begin : power_calc
            // Extend input to 32-bit signed for multiplication headroom
            wire signed [31:0] num_ext = $signed(nums_i[i]);

            // Power 1 (Input)
            assign p1[i] = num_ext;

            // Power 2 (Input * Input)
            assign p2[i] = num_ext * num_ext;

            // Power 3 (Power 2 * Input)
            assign p3[i] = p2[i] * num_ext;

            // Power 4 (Power 2 * Power 2)
            assign p4[i] = p2[i] * p2[i];

            // Power 5 (Power 4 * Input)
            assign p5[i] = p4[i] * num_ext;

            // Output Mux for Power Selection
            always @(*) begin
                case (power_i)
                    3'd0:   results_o[i] = 32'sd1;          // Power 0: 1
                    3'd1:   results_o[i] = p1[i];           // Power 1
                    3'd2:   results_o[i] = p2[i];           // Power 2
                    3'd3:   results_o[i] = p3[i];           // Power 3
                    3'd4:   results_o[i] = p4[i];           // Power 4
                    3'd5:   results_o[i] = p5[i];           // Power 5
                    default: results_o[i] = 32'sd0;         // Default case (safe)
                endcase
            end
        end
    endgenerate

endmodule