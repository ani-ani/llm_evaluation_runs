module insertion_point_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] arr_len,
    input [7:0] target,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [3:0] left;
    reg [3:0] right;
    reg [3:0] mid;
    reg [7:0] arr_mid;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            left <= 4'd0;
            right <= 4'd0;
            mid <= 4'd0;
            arr_mid <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        left <= 4'd0;
                        right <= arr_len;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Binary search logic
                    if (left < right) begin
                        mid <= (left + right) >> 1;
                        arr_mid <= arr[mid];
                        
                        if (arr_mid <= target) begin
                            left <= mid + 4'd1;
                        end else begin
                            right <= mid;
                        end
                    end else begin
                        result <= left;
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= left;
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