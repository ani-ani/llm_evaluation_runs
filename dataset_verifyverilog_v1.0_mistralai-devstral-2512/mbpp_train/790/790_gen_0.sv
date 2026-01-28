module even_index_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= CHECK;
                        index <= 4'd0;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check current index
                    if (index[0] == 1'b0) begin
                        // Even index - check for even value
                        if (arr[index][0] != 1'b0) begin
                            result <= 1'b0;
                            state <= FINISH;
                        end
                    end else begin
                        // Odd index - check for odd value
                        if (arr[index][0] != 1'b1) begin
                            result <= 1'b0;
                            state <= FINISH;
                        end
                    end
                    
                    // Move to next index or finish
                    if (index == 4'd15) begin
                        result <= 1'b1;
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
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