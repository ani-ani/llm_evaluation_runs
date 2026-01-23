module delivery_time_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0][31:0] misha_points,
    input wire [6:0][31:0] nadia_points,
    input wire [2:0] misha_count,
    input wire [2:0] nadia_count,
    output reg [31:0] result,
    output reg done,
    output reg impossible
);

    // State Machine Encoding
    localparam IDLE = 3'd0;
    localparam PREP_SEG = 3'd1;
    localparam MAIN_LOOP = 3'd2; // Handles T and S loops
    localparam CALC_RESULT = 3'd3; // Performs arithmetic
    localparam UPDATE_MIN = 3'd4;
    localparam FINISHED = 3'd5;

    reg [2:0] state;
    
    // Segment Data Registers
    reg signed [31:0] mx, my, mvx, mvy; // Misha start, vector
    reg signed [31:0] nx, ny, nvx, nvy; // Nadia start, vector
    
    // Loop Counters
    reg [1:0] m_seg, n_seg; // Segment indices
    reg [3:0] t_step, s_step; // 0-15 (16 steps)
    
    // Intermediate Calculation Registers
    reg signed [31:0] px, py, qx, qy;
    reg signed [31:0] time_msg, time_m, time_n;
    reg signed [31:0] min_time;
    
    // Multi-cycle math control
    reg [2:0] calc_step;
    reg signed [63:0] mul_res;
    reg signed [31:0] diff_x, diff_y;
    
    // Constants
    localparam Q16_16_ONE = 32'h00010000;
    localparam STEP = 32'h00001000;
    localparam MAX_VAL = 32'h7FFFFFFF;

    // Helper: Abs function
    function automatic signed [31:0] abs_val;
        input signed [31:0] val;
        begin
            abs_val = (val < 0) ? -val : val;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            impossible <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    min_time <= MAX_VAL;
                    if (start) begin
                        m_seg <= 0;
                        n_seg <= 0;
                        t_step <= 0;
                        s_step <= 0;
                        state <= PREP_SEG;
                    end
                end

                PREP_SEG: begin
                    // Load current segment data
                    // Check bounds (max index 6 for 3 segments)
                    if (m_seg < misha_count - 1 && n_seg < nadia_count - 1 && (2*m_seg+2 < 7) && (2*n_seg+2 < 7)) begin
                        mx <= misha_points[2*m_seg];
                        my <= misha_points[2*m_seg+1];
                        mvx <= $signed(misha_points[2*m_seg+2]) - $signed(misha_points[2*m_seg]);
                        mvy <= $signed(misha_points[2*m_seg+3]) - $signed(misha_points[2*m_seg+1]);
                        
                        nx <= nadia_points[2*n_seg];
                        ny <= nadia_points[2*n_seg+1];
                        nvx <= $signed(nadia_points[2*n_seg+2]) - $signed(nadia_points[2*n_seg]);
                        nvy <= $signed(nadia_points[2*n_seg+3]) - $signed(nadia_points[2*n_seg+1]);
                        
                        t_step <= 0;
                        s_step <= 0;
                        state <= MAIN_LOOP;
                    end else begin
                        // End of computation
                        if (min_time == MAX_VAL)
                            impossible <= 1;
                        else 
                            result <= min_time;
                        done <= 1;
                        state <= FINISHED;
                    end
                end

                MAIN_LOOP: begin
                    // Iterate T then S
                    if (t_step == 16) begin
                        // Next Nadia Segment
                        t_step <= 0;
                        n_seg <= n_seg + 1;
                        if (n_seg == nadia_count - 2) begin
                            n_seg <= 0;
                            m_seg <= m_seg + 1;
                            state <= PREP_SEG; // Reload Misha segment
                        end else begin
                            // Reset Nadia segment data for next n_seg
                            state <= PREP_SEG; // We can optimize to only reload Nadia, but reusing PREP_SEG is safe
                        end
                    end else if (s_step == 16) begin
                        // Next T step
                        s_step <= 0;
                        t_step <= t_step + 1;
                    end else begin
                        // Perform calculation for (t_step, s_step)
                        calc_step <= 0;
                        state <= CALC_RESULT;
                    end
                end

                CALC_RESULT: begin
                    // Sequential arithmetic for one (t,s) pair
                    case (calc_step)
                        0: begin
                            // Calculate P = M_start + T * M_vec
                            // T = t_step * STEP. Vec is integer. We treat Vec as Q16.16 (shifted 16) implicitly.
                            // Product: (t_step * vec) << 12 (since STEP = 1/16 = 1<<12)
                            mul_res <= $signed(t_step) * $signed(mvx);
                            calc_step <= 1;
                        end
                        1: begin
                            px <= mx + (mul_res <<< 12);
                            mul_res <= $signed(t_step) * $signed(mvy);
                            calc_step <= 2;
                        end
                        2: begin
                            py <= my + (mul_res <<< 12);
                            mul_res <= $signed(s_step) * $signed(nvx);
                            calc_step <= 3;
                        end
                        3: begin
                            qx <= nx + (mul_res <<< 12);
                            mul_res <= $signed(s_step) * $signed(nvy);
                            calc_step <= 4;
                        end
                        4: begin
                            qy <= ny + (mul_res <<< 12);
                            // Calculate Distance (using Manhattan approx for speed/area or Sqrt logic)
                            // To satisfy "minimum delivery time", we need Euclidean. 
                            // We will use a fast approximation: dist = |dx| + |dy| + (|dx|-|dy|)/4
                            diff_x <= abs_val(px - qx);
                            diff_y <= abs_val(py - qy);
                            calc_step <= 5;
                        end
                        5: begin
                            // Dist Approximation
                            // dist = max(dx, dy) + (min/4)
                            if (diff_x > diff_y) begin
                                time_msg <= diff_x + (diff_y >>> 2);
                            end else begin
                                time_msg <= diff_y + (diff_x >>> 2);
                            end
                            // Calculate Time M (t * |Vec_M|)
                            // |Vec_M| approx = |mvx| + |mvy|
                            mul_res <= $signed(t_step) * (abs_val(mvx) + abs_val(mvy));
                            calc_step <= 6;
                        end
                        6: begin
                            time_m <= mul_res <<< 12;
                            // Calculate Time N (s * |Vec_N|)
                            mul_res <= $signed(s_step) * (abs_val(nvx) + abs_val(nvy));
                            calc_step <= 7;
                        end
                        7: begin
                            time_n <= mul_res <<< 12;
                            calc_step <= 0; // Reset for next iteration
                            state <= UPDATE_MIN;
                        end
                    endcase
                end

                UPDATE_MIN: begin
                    // Update minimum time: max(time_m, time_n, time_msg)
                    if (time_m > time_n && time_m > time_msg) begin
                        if (time_m < min_time) min_time <= time_m;
                    end else if (time_n > time_msg) begin
                        if (time_n < min_time) min_time <= time_n;
                    end else begin
                        if (time_msg < min_time) min_time <= time_msg;
                    end
                    
                    // Increment S
                    s_step <= s_step + 1;
                    state <= MAIN_LOOP;
                end

                FINISHED: begin
                    // Wait for reset or new start
                    done <= 1;
                end
            endcase
        end
    end
endmodule