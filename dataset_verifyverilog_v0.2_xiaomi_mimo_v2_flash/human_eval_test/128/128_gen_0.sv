module prod_signs (
    input clk,
    input rst_n,
    input start,
    input [2:0] arr_len,
    input [7:0] arr_data_0,
    input [7:0] arr_data_1,
    input [7:0] arr_data_2,
    input [7:0] arr_data_3,
    input [7:0] arr_data_4,
    input [7:0] arr_data_5,
    input [7:0] arr_data_6,
    input [7:0] arr_data_7,
    output reg [31:0] result,
    output reg valid
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam CALCULATE = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [2:0] count;
    reg [31:0] sum_mag;
    reg sign_prod; // 0: zero, 1: positive/negative (tracked by parity below)
    reg has_zero;
    reg neg_parity; // 0: even negatives (positive result), 1: odd negatives (negative result)
    
    // Combinational logic for current element access
    wire [7:0] current_elem;
    
    assign current_elem = (
        (count == 3'd0) ? arr_data_0 :
        (count == 3'd1) ? arr_data_1 :
        (count == 3'd2) ? arr_data_2 :
        (count == 3'd3) ? arr_data_3 :
        (count == 3'd4) ? arr_data_4 :
        (count == 3'd5) ? arr_data_5 :
        (count == 3'd6) ? arr_data_6 :
        arr_data_7
    );

    // Combinational logic for magnitude calculation
    wire [7:0] abs_val;
    assign abs_val = (current_elem[7] && (arr_len != 0)) ? (~current_elem + 1'b1) : current_elem;

    // State Machine and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            result <= 32'b0;
            sum_mag <= 32'b0;
            count <= 3'b0;
            sign_prod <= 1'b0; // Default to zero product state
            has_zero <= 1'b0;
            neg_parity <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        count <= 3'b0;
                        sum_mag <= 32'b0;
                        has_zero <= 1'b0;
                        neg_parity <= 1'b0;
                        
                        if (arr_len == 3'b0) begin
                            // Edge case: Empty array
                            state <= DONE;
                            sign_prod <= 1'b0; // Implicit zero
                            result <= 32'b0;
                        end else begin
                            state <= CALCULATE;
                            sign_prod <= 1'b1; // Assume non-zero product initially
                        end
                    end
                end

                CALCULATE: begin
                    // Process element at current count
                    if (current_elem == 8'sd0) begin
                        has_zero <= 1'b1;
                    end else if (current_elem[7]) begin
                        // Negative number (non-zero)
                        neg_parity <= neg_parity ^ 1'b1;
                    end

                    // Add magnitude to sum
                    sum_mag <= sum_mag + {24'b0, abs_val};

                    // Increment count
                    if (count == arr_len - 1'b1) begin
                        state <= DONE;
                        count <= 3'b0;\ // Reset for IDLE
                    end else begin
                        count <= count + 1'b1;
                    end
                end

                DONE: begin
                    // Calculate final result
                    if (sign_prod == 1'b0 || has_zero) begin
                        result <= 32'b0;
                    end else if (neg_parity) begin
                        // Odd number of negatives, result is negative
                        result <= -sum_mag;
                    end else begin
                        // Even number of negatives, result is positive
                        result <= sum_mag;
                    end
                    
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
