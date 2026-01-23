module max_prefixes (
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [7:0] s,
    input [7:0] t,
    output reg [15:0] ans,
    output reg done
);
    
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] cur;
    reg [3:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Combinational logic
    wire subtract_s = s[index];
    wire subtract_t = (t[index] == 0) ? 1'b1 : 1'b0;
    wire signed [9:0] raw_next = ($signed({1'b0, cur}) * 2) - subtract_s - subtract_t;
    wire [7:0] clamped_cur = (raw_next > $signed({1'b0, k})) ? k : (raw_next < 0 ? 0 : raw_next[7:0]);
    wire [15:0] next_ans = ans + clamped_cur;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cur <= 8'd1;
            ans <= 16'd0;
            index <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        cur <= 8'd1;
                        ans <= 16'd0;
                        index <= 4'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    cur <= clamped_cur;
                    ans <= next_ans;
                    index <= index + 4'd1;
                    
                    if (index == 4'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                        done <= 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule