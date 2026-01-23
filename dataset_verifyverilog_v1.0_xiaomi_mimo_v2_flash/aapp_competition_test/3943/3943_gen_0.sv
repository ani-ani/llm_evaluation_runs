module CardArrangementOptimizer(
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

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_EDGE = 3'd1;
    localparam [2:0] COMPUTE_SCORE = 3'd2;
    localparam [2:0] FIND_MAX = 3'd3;
    localparam [2:0] BUILD_ARRANGEMENT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] p;          // 0 to 4 (since MAX_A=4)
    reg signed [7:0] best_score;
    reg [3:0] best_p;
    reg [3:0] best_q;
    reg [3:0] best_r;
    reg signed [7:0] current_score;
    reg [3:0] q_val;
    reg [3:0] r_val;
    reg [3:0] large_o;
    reg [3:0] small_o;
    reg [3:0] gap_idx;
    reg [3:0] gap_val;
    reg [4:0] bit_idx;
    reg signed [7:0] sum_o_sq;
    reg signed [7:0] sum_x_sq;
    reg [4:0] a_ext;
    reg [4:0] b_ext;
    reg [4:0] p_ext;
    reg [4:0] gaps;
    reg [4:0] temp_q;
    reg [4:0] temp_r;
    
    // Combinational helper signals
    wire [4:0] sum_o_sq_wire;
    wire [4:0] sum_x_sq_wire;
    wire [4:0] gap_calc;
    
    assign sum_o_sq_wire = (a - p + 1) * (a - p + 1) + p - 1;
    assign gap_calc = p + 1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            score <= 8'sd0;
            arrangement <= 8'd0;
            length <= 4'd0;
            p <= 3'd0;
            best_score <= 8'sd0;
            best_p <= 4'd0;
            best_q <= 4'd0;
            best_r <= 4'd0;
            current_score <= 8'sd0;
            q_val <= 4'd0;
            r_val <= 4'd0;
            large_o <= 4'd0;
            small_o <= 4'd0;
            gap_idx <= 4'd0;
            gap_val <= 4'd0;
            bit_idx <= 5'd0;
            a_ext <= 5'd0;
            b_ext <= 5'd0;
            p_ext <= 5'd0;
            gaps <= 5'd0;
            temp_q <= 5'd0;
            temp_r <= 5'd0;
            sum_o_sq <= 8'sd0;
            sum_x_sq <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    p <= 3'd1;
                    if (start) begin
                        if (a == 3'd0) begin
                            score <= -({5'd0, b} * {5'd0, b});
                            arrangement <= 8'd0;
                            length <= {1'b0, b};
                            state <= FINISH;
                        end else if (b == 3'd0) begin
                            score <= {2'd0, a} * {2'd0, a};
                            arrangement <= {8'd0[7:8-{1'b0, a}], {(1'b0, a){1'b1}}};
                            length <= {1'b0, a};
                            state <= FINISH;
                        end else begin
                            best_score <= 8'sd0;
                            p <= 3'd1;
                            state <= CHECK_EDGE;
                        end
                    end
                end
                
                CHECK_EDGE: begin
                    if (p > a) begin
                        p <= 3'd1;
                        large_o <= a - best_p + 1;
                        small_o <= 3'd1;
                        gaps <= best_p + 1;
                        gap_idx <= 4'd0;
                        bit_idx <= 5'd0;
                        arrangement <= 8'd0;
                        state <= BUILD_ARRANGEMENT;
                    end else begin
                        p_ext <= {2'd0, p};
                        a_ext <= {2'd0, a};
                        gaps <= {2'd0, p} + 5'd1;
                        temp_q <= ({2'd0, b} + {2'd0, p}) / ({2'd0, p} + 5'd1);
                        temp_r <= ({2'd0, b} + {2'd0, p}) % ({2'd0, p} + 5'd1);
                        sum_o_sq <= {3'd0, ({3'd0, a} - {2'd0, p} + 5'd1) * ({3'd0, a} - {2'd0, p} + 5'd1) + {2'd0, p} - 5'd1};
                        state <= COMPUTE_SCORE;
                    end
                end
                
                COMPUTE_SCORE: begin
                    q_val <= temp_q[3:0];
                    r_val <= temp_r[3:0];
                    sum_x_sq <= {3'd0, temp_r * (temp_q + 5'd1) * (temp_q + 5'd1)} + 
                                {3'd0, (gaps - temp_r) * temp_q * temp_q};
                    current_score <= sum_o_sq - {3'd0, temp_r * (temp_q + 5'd1) * (temp_q + 5'd1)} - 
                                   {3'd0, (gaps - temp_r) * temp_q * temp_q};
                    state <= FIND_MAX;
                end
                
                FIND_MAX: begin
                    if (current_score > best_score) begin
                        best_score <= current_score;
                        best_p <= {1'd0, p};
                        best_q <= q_val;
                        best_r <= r_val;
                    end
                    p <= p + 3'd1;
                    state <= CHECK_EDGE;
                end
                
                BUILD_ARRANGEMENT: begin
                    if (gap_idx <= best_p) begin
                        if (gap_idx < best_r) begin
                            gap_val <= best_q + 3'd1;
                        end else begin
                            gap_val <= best_q;
                        end
                        
                        // Add gap (x's)
                        if (gap_val > 0) begin
                            if (gap_val > (8 - bit_idx)) begin
                                gap_val <= 8 - bit_idx;
                            end
                        end
                        state <= BUILD_ARRANGEMENT; // Continue on next cycle
                    end else begin
                        length <= {1'd0, a} + {1'd0, b};
                        score <= best_score;
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
    
    // Combinational process for building arrangement
    always @(*) begin
        if (state == BUILD_ARRANGEMENT && bit_idx < 8'd8 && gap_idx <= best_p) begin
            if (gap_idx < best_r) begin
                gap_val = best_q + 4'd1;
            end else begin
                gap_val = best_q;
            end
            
            // Fill x's
            if (gap_val > 0) begin
                if (bit_idx < 8'd8) begin
                    arrangement[bit_idx] = 1'b0;
                    bit_idx = bit_idx + 5'd1;
                    if (gap_val > 1 && bit_idx < 8'd8) begin
                        arrangement[bit_idx] = 1'b0;
                        bit_idx = bit_idx + 5'd1;
                        if (gap_val > 2 && bit_idx < 8'd8) begin
                            arrangement[bit_idx] = 1'b0;
                            bit_idx = bit_idx + 5'd1;
                            if (gap_val > 3 && bit_idx < 8'd8) begin
                                arrangement[bit_idx] = 1'b0;
                                bit_idx = bit_idx + 5'd1;
                            end
                        end
                    end
                end
            end
            
            // Fill o's
            if (bit_idx < 8'd8) begin
                if (gap_idx == 0) begin
                    if (large_o > 0 && bit_idx < 8'd8) begin
                        arrangement[bit_idx] = 1'b1;
                        bit_idx = bit_idx + 5'd1;
                        if (large_o > 1 && bit_idx < 8'd8) begin
                            arrangement[bit_idx] = 1'b1;
                            bit_idx = bit_idx + 5'd1;
                            if (large_o > 2 && bit_idx < 8'd8) begin
                                arrangement[bit_idx] = 1'b1;
                                bit_idx = bit_idx + 5'd1;
                                if (large_o > 3 && bit_idx < 8'd8) begin
                                    arrangement[bit_idx] = 1'b1;
                                    bit_idx = bit_idx + 5'd1;
                                end
                            end
                        end
                    end
                end else if (gap_idx < best_p) begin
                    if (small_o > 0 && bit_idx < 8'd8) begin
                        arrangement[bit_idx] = 1'b1;
                        bit_idx = bit_idx + 5'd1;
                    end
                end
            end
            
            gap_idx = gap_idx + 4'd1;
        end
    end

endmodule