module min_sublist_finder(
    input clk,
    input rst_n,
    input start,
    input [63:0] sublist_packed [0:3],
    input [3:0] valid_len [0:3],
    output reg [63:0] result_packed,
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [1:0] current_idx;
    reg [3:0] min_len;
    reg [1:0] min_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd60;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_packed <= 64'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            current_idx <= 2'd0;
            min_len <= 4'd0;
            min_idx <= 2'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        current_idx <= 2'd0;
                        min_len <= valid_len[0];
                        min_idx <= 2'd0;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (current_idx < 3) begin
                        current_idx <= current_idx + 2'd1;
                        if (valid_len[current_idx] < min_len) begin
                            min_len <= valid_len[current_idx];
                            min_idx <= current_idx;
                        end
                    end
                    
                    if (current_idx == 3 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result_packed <= sublist_packed[min_idx];
                    result_len <= min_len;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule