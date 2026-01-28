module is_sorted(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] length,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [2:0] index;
    reg [7:0] current_val;
    reg [7:0] next_val;
    reg [1:0] dup_count;
    reg violation;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            current_val <= 8'd0;
            next_val <= 8'd0;
            dup_count <= 2'd0;
            violation <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                        index <= 3'd0;
                        current_val <= arr[0];
                        dup_count <= 2'd1;
                        violation <= 1'b0;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've reached the end
                    if (index == length - 1) begin
                        state <= FINISH;
                    end else begin
                        next_val <= arr[index + 1];
                        
                        // Check if sorted
                        if (current_val > next_val) begin
                            violation <= 1'b1;
                        end
                        
                        // Check duplicates
                        if (current_val == next_val) begin
                            dup_count <= dup_count + 2'd1;
                            if (dup_count > 2'd2) begin
                                violation <= 1'b1;
                            end
                        end else begin
                            dup_count <= 2'd1;
                        end
                        
                        // Move to next element
                        index <= index + 3'd1;
                        current_val <= next_val;
                        
                        // Early exit if violation found
                        if (violation || cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    result <= ~violation;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule