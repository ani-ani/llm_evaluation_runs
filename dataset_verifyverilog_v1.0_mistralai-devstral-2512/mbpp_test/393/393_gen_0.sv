module FindMaxSublist(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] lists [0:4][0:7],
    input wire [3:0] sublist_lens [0:4],
    output reg [3:0] max_len,
    output reg [2:0] max_idx,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;
    
    reg [3:0] current_max_len;
    reg [2:0] current_max_idx;
    reg [2:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_len <= 4'd0;
            max_idx <= 3'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_max_len <= 4'd0;
            current_max_idx <= 3'd0;
            i <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        current_max_len <= 4'd0;
                        current_max_idx <= 3'd0;
                        i <= 3'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compare current sublist length with max
                    if (sublist_lens[i] > current_max_len) begin
                        current_max_len <= sublist_lens[i];
                        current_max_idx <= i;
                    end
                    
                    // Move to next sublist or finish
                    if (i == 4) begin
                        state <= FINISH;
                    end else begin
                        i <= i + 3'd1;
                    end
                end
                
                FINISH: begin
                    max_len <= current_max_len;
                    max_idx <= current_max_idx;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule