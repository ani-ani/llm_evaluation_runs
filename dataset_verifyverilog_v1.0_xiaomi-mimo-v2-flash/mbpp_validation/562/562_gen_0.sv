module longest_sublist_length(
    input clk,
    input rst_n,
    input start,
    input [7:0] valid,
    input [3:0] lengths [0:7],
    output reg [3:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state;
    reg [2:0] index;          // 0-7 for sublist iteration
    reg [3:0] current_max;    // Current maximum length
    reg [2:0] cycle_counter;  // Prevent infinite loops
    localparam [2:0] MAX_CYCLES = 3'd7;  // 8 sublists, 1 cycle each
    
    // Sequential FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 3'd0;
            current_max <= 4'd0;
            cycle_counter <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    current_max <= 4'd0;
                    cycle_counter <= 3'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 3'd1;
                    
                    // Check current sublist if valid
                    if (valid[index]) begin
                        if (lengths[index] > current_max) begin
                            current_max <= lengths[index];
                        end
                    end
                    
                    // Move to next sublist or finish
                    if (index == 3'd7) begin
                        state <= COMPLETE;
                    end else begin
                        index <= index + 3'd1;
                    end
                    
                    // Safety timeout
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    result <= current_max;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule