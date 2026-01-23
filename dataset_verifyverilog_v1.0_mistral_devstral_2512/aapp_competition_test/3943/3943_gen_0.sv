module CardArrangementOptimizer #(
    parameter MAX_A = 4,
    parameter MAX_B = 4
)(
    input clk,
    input rst_n,
    input start,
    input [2:0] a,
    input [2:0] b,
    output reg done,
    output reg signed [7:0] score,
    output reg [7:0] arrangement,
    output reg [3:0] length
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;
    
    // Internal registers for computation
    reg [2:0] p;
    reg [2:0] best_p;
    reg [2:0] best_q;
    reg [2:0] best_r;
    reg signed [7:0] max_score;
    reg [2:0] gaps;
    reg [2:0] q;
    reg [2:0] r;
    reg [2:0] large_o;
    reg [2:0] small_o;
    reg [2:0] gap_sizes [0:4];
    reg [7:0] temp_arrangement;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            score <= 8'd0;
            arrangement <= 8'd0;
            length <= 4'd0;
            cycle_count <= 8'd0;
            p <= 3'd0;
            best_p <= 3'd0;
            best_q <= 3'd0;
            best_r <= 3'd0;
            max_score <= 8'd0;
            gaps <= 3'd0;
            q <= 3'd0;
            r <= 3'd0;
            large_o <= 3'd0;
            small_o <= 3'd0;
            temp_arrangement <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        p <= 3'd1;
                        max_score <= 8'd0;
                        best_p <= 3'd0;
                        best_q <= 3'd0;
                        best_r <= 3'd0;
                        if (a == 3'd0) begin
                            score <= -({1'b0, b} * {1'b0, b});
                            arrangement <= 8'd0;
                            length <= b;
                            state <= FINISH;
                        end else if (b == 3'd0) begin
                            score <= {1'b0, a} * {1'b0, a};
                            arrangement <= {8{a[0]}};
                            length <= a;
                            state <= FINISH;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        if (p <= a) begin
                            // Calculate sum_o_sq
                            reg [2:0] sum_o_sq;
                            sum_o_sq = (a - p + 3'd1) * (a - p + 3'd1) + p - 3'd1;
                            
                            // Calculate gaps, q, r
                            gaps = p + 3'd1;
                            q = b / gaps;
                            r = b % gaps;
                            
                            // Calculate sum_x_sq
                            reg [7:0] sum_x_sq;
                            sum_x_sq = r * (q + 3'd1) * (q + 3'd1) + (gaps - r) * q * q;
                            
                            // Calculate score_candidate
                            reg signed [7:0] score_candidate;
                            score_candidate = {1'b0, sum_o_sq} - {1'b0, sum_x_sq};
                            
                            // Update best parameters
                            if (score_candidate > max_score) begin
                                max_score <= score_candidate;
                                best_p <= p;
                                best_q <= q;
                                best_r <= r;
                            end
                            
                            p <= p + 3'd1;
                        end else begin
                            // Build arrangement
                            large_o = a - best_p + 3'd1;
                            small_o = 3'd1;
                            
                            // Calculate gap sizes
                            integer i;
                            for (i = 0; i < 5; i = i + 1) begin
                                if (i < best_p + 3'd1) begin
                                    gap_sizes[i] <= (i < best_r) ? best_q + 3'd1 : best_q;
                                end else begin
                                    gap_sizes[i] <= 3'd0;
                                end
                            end
                            
                            // Build arrangement
                            temp_arrangement <= 8'd0;
                            integer pos;
                            pos = 0;
                            
                            // First gap
                            for (i = 0; i < gap_sizes[0]; i = i + 1) begin
                                if (pos < 8) begin
                                    temp_arrangement[pos] <= 1'b0;
                                    pos = pos + 1;
                                end
                            end
                            
                            // Large 'o' block
                            for (i = 0; i < large_o; i = i + 1) begin
                                if (pos < 8) begin
                                    temp_arrangement[pos] <= 1'b1;
                                    pos = pos + 1;
                                end
                            end
                            
                            // Middle gaps and small 'o' blocks
                            for (i = 1; i < best_p; i = i + 1) begin
                                for (integer j = 0; j < gap_sizes[i]; j = j + 1) begin
                                    if (pos < 8) begin
                                        temp_arrangement[pos] <= 1'b0;
                                        pos = pos + 1;
                                    end
                                end
                                for (integer j = 0; j < small_o; j = j + 1) begin
                                    if (pos < 8) begin
                                        temp_arrangement[pos] <= 1'b1;
                                        pos = pos + 1;
                                    end
                                end
                            end
                            
                            // Last gap
                            for (i = 0; i < gap_sizes[best_p]; i = i + 1) begin
                                if (pos < 8) begin
                                    temp_arrangement[pos] <= 1'b0;
                                    pos = pos + 1;
                                end
                            end
                            
                            score <= max_score;
                            arrangement <= temp_arrangement;
                            length <= a + b;
                            state <= FINISH;
                        end
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