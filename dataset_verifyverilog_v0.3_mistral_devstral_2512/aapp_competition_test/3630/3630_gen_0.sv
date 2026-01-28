module string_puzzle_solver #(
    parameter N = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s1 [0:N-1],
    input wire [7:0] s2 [0:N-1],
    output reg [15:0] result,
    output reg done
);

// State declarations
localparam [1:0] IDLE = 2'd0;
localparam [1:0] PROCESS = 2'd1;
localparam [1:0] FINISH = 2'd2;

// Internal registers
reg [1:0] state;
reg [7:0] prev_pos, prev_neg;
reg [15:0] acc;
reg [$clog2(N)-1:0] idx;
reg [7:0] current_pos, current_neg;

// Combinational logic for current values
always @(*) begin
    current_pos = (s2[idx] > s1[idx]) ? (s2[idx] - s1[idx]) : 8'd0;
    current_neg = (s1[idx] > s2[idx]) ? (s1[idx] - s2[idx]) : 8'd0;
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 16'd0;
        acc <= 16'd0;
        prev_pos <= 8'd0;
        prev_neg <= 8'd0;
        idx <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= PROCESS;
                    idx <= 8'd0;
                    acc <= 16'd0;
                    prev_pos <= 8'd0;
                    prev_neg <= 8'd0;
                end
            end
            
            PROCESS: begin
                // Calculate increments
                reg [7:0] inc_pos = (current_pos > prev_pos) ? (current_pos - prev_pos) : 8'd0;
                reg [7:0] inc_neg = (current_neg > prev_neg) ? (current_neg - prev_neg) : 8'd0;
                
                // Update accumulator
                acc <= acc + inc_pos + inc_neg;
                
                // Update previous values
                prev_pos <= current_pos;
                prev_neg <= current_neg;
                
                // Move to next index
                idx <= idx + 8'd1;
                
                // Check if done
                if (idx == N-1) begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                // Final calculation for last element
                reg [7:0] final_inc_pos = (current_pos > prev_pos) ? (current_pos - prev_pos) : 8'd0;
                reg [7:0] final_inc_neg = (current_neg > prev_neg) ? (current_neg - prev_neg) : 8'd0;
                
                result <= acc + final_inc_pos + final_inc_neg;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule