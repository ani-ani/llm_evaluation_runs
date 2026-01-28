module BetweenPlanets(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] p1,
    input wire [2:0] p2,
    output reg [63:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] VALIDATE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] low;
    reg [2:0] high;
    reg [3:0] iter;           // 0 to 8 iterations
    reg [3:0] ptr;            // Write pointer 0-7
    reg [31:0] temp_result_hi;  // Upper 32 bits
    reg [31:0] temp_result_lo;  // Lower 32 bits
    reg invalid_input;
    reg found_any;

    // Helper signals for combinations
    wire [2:0] p1_eff;
    wire [2:0] p2_eff;
    wire [2:0] low_calc;
    wire [2:0] high_calc;
    wire [2:0] iter_val;
    wire valid_check;

    assign p1_eff = p1;
    assign p2_eff = p2;
    assign low_calc = (p1 < p2) ? p1 : p2;
    assign high_calc = (p2 < p1) ? p2 : p1;
    assign iter_val = iter[2:0];
    assign valid_check = (p1 < 8) && (p2 < 8) && (p1 != p2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            low <= 3'd0;
            high <= 3'd0;
            iter <= 4'd0;
            ptr <= 4'd0;
            temp_result_hi <= 32'd0;
            temp_result_lo <= 32'd0;
            invalid_input <= 1'b0;
            found_any <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= VALIDATE;
                        // Pre-calculate bounds for next state
                        low <= (p1 < p2) ? p1 : p2;
                        high <= (p2 < p1) ? p2 : p1;
                    end
                end

                VALIDATE: begin
                    ptr <= 4'd0;
                    iter <= 4'd0;
                    temp_result_hi <= 32'd0;
                    temp_result_lo <= 32'd0;
                    found_any <= 1'b0;
                    
                    // Check for invalid inputs (out of range or equal)
                    if (!valid_check) begin
                        invalid_input <= 1'b1;
                        state <= FINISH;
                    end else begin
                        invalid_input <= 1'b0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Iterate through planets 0-7
                    if (iter < 8) begin
                        // Check if current planet is strictly between bounds
                        if (iter_val > low && iter_val < high) begin
                            found_any <= 1'b1;
                            
                            // Write to correct byte position
                            if (ptr < 4) begin
                                // Write to low 32 bits (bytes 0-3)
                                case (ptr)
                                    4'd0: temp_result_lo[7:0] <= {5'd0, iter_val};
                                    4'd1: temp_result_lo[15:8] <= {5'd0, iter_val};
                                    4'd2: temp_result_lo[23:16] <= {5'd0, iter_val};
                                    4'd3: temp_result_lo[31:24] <= {5'd0, iter_val};
                                endcase
                            end else begin
                                // Write to high 32 bits (bytes 4-7)
                                case (ptr)
                                    4'd4: temp_result_hi[7:0] <= {5'd0, iter_val};
                                    4'd5: temp_result_hi[15:8] <= {5'd0, iter_val};
                                    4'd6: temp_result_hi[23:16] <= {5'd0, iter_val};
                                    4'd7: temp_result_hi[31:24] <= {5'd0, iter_val};
                                endcase
                            end
                            ptr <= ptr + 4'd1;
                        end
                        iter <= iter + 4'd1;
                    end else begin
                        // Finished iteration
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    
                    if (invalid_input || !found_any) begin
                        // Output all 0xFF for invalid or no planets found
                        result <= 64'hFFFFFFFFFFFFFFFF;
                    end else begin
                        // Combine temp results
                        result <= {temp_result_hi, temp_result_lo};
                    end
                    
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule