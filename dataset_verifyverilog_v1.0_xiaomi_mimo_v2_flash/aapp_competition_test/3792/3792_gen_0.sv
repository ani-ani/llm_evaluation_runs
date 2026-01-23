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
    // Internal registers
    reg [7:0] cur;
    reg [3:0] index;
    reg state;
    
    // State definitions
    localparam IDLE = 0;
    localparam COMPUTE = 1;
    
    // Combinational logic
    wire subtract_s;
    wire subtract_t;
    wire signed [9:0] raw_next;
    wire [7:0] clamped_cur;
    wire [15:0] next_ans;
    wire signed [9:0] k_signed;
    
    assign subtract_s = s[index];
    assign subtract_t = (t[index] == 0) ? 1'b1 : 1'b0;
    assign k_signed = $signed({1'b0, k});
    assign raw_next = ($signed({1'b0, cur}) * 2) - subtract_s - subtract_t;
    assign clamped_cur = (raw_next > k_signed) ? k : (raw_next < 0 ? 0 : raw_next[7:0]);
    assign next_ans = ans + clamped_cur;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur <= 8'd1;
            ans <= 16'd0;
            index <= 4'd0;
            state <= IDLE;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        cur <= 8'd1;
                        ans <= 16'd0;
                        index <= 4'd0;
                        state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    cur <= clamped_cur;
                    ans <= next_ans;
                    index <= index + 1;
                    if (index == 7) begin
                        state <= IDLE;
                        done <= 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule