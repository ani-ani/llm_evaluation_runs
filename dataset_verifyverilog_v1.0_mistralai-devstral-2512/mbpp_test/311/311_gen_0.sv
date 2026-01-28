module set_leftmost_unset_bit(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [7:0] temp_result;
    reg [2:0] bit_index;
    reg found_unset;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            temp_result <= 8'd0;
            bit_index <= 3'd0;
            found_unset <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        temp_result <= n_in;
                        bit_index <= 3'd7;
                        found_unset <= 1'b0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if all bits are set (255)
                    if (temp_result == 8'd255) begin
                        result <= 8'd255;
                        state <= FINISH;
                    end else if (!found_unset) begin
                        // Check current bit
                        if (!temp_result[bit_index]) begin
                            // Found unset bit, set it
                            temp_result[bit_index] <= 1'b1;
                            found_unset <= 1'b1;
                            result <= temp_result;
                            state <= FINISH;
                        end else begin
                            // Move to next lower bit
                            bit_index <= bit_index - 3'd1;
                            
                            // If we've checked all bits and none were unset
                            if (bit_index == 3'd0 && !found_unset) begin
                                result <= temp_result;
                                state <= FINISH;
                            end
                        end
                    end else begin
                        result <= temp_result;
                        state <= FINISH;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= temp_result;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule