module process_gradient (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] w,       // Width of matrix (1-10000)
    input wire [15:0] h,       // Height of matrix (1-10000)
    input wire [15:0] pos_r,   // Start row (0-indexed, 0 to h-1)
    input wire [15:0] pos_c,   // Start column (0-indexed, 0 to w-1)
    output reg [31:0] result,  // Result value (could be negative)
    output reg done            // Computation complete signal
);

    // State machine states
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CALC_M        = 3'd1;
    localparam [2:0] CHECK_DIR     = 3'd2;
    localparam [2:0] CALC_NEW_POS  = 3'd3;
    localparam [2:0] CALC_RESULT   = 3'd4;
    localparam [2:0] FINISH        = 3'd5;
    
    reg [2:0] state;
    reg [15:0] w_reg, h_reg, r_reg, c_reg;
    reg [31:0] m_val;           // Calculated m value
    reg [31:0] new_r;            // New row after movement
    reg [31:0] new_c;            // New column after movement
    reg [31:0] step_result;      // Intermediate result
    reg [1:0] direction;         // 0:up, 1:right, 2:down, 3:left
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'b0;
            w_reg <= 16'b0;
            h_reg <= 16'b0;
            r_reg <= 16'b0;
            c_reg <= 16'b0;
            m_val <= 32'b0;
            new_r <= 32'b0;
            new_c <= 32'b0;
            step_result <= 32'b0;
            direction <= 2'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        w_reg <= w;
                        h_reg <= h;
                        r_reg <= pos_r;
                        c_reg <= pos_c;
                        state <= CALC_M;
                    end
                end
                
                CALC_M: begin
                    // Calculate m = 2*w*h - (w + h)
                    // Use 32-bit to avoid overflow (max: 2*10000*10000 - 20000 ≈ 200M)
                    m_val <= (2 * (w_reg * h_reg)) - (w_reg + h_reg);
                    state <= CHECK_DIR;
                end
                
                CHECK_DIR: begin
                    // Determine direction based on r + c
                    if ((r_reg + c_reg) < m_val) begin
                        if (r_reg == 16'd0) begin
                            direction <= 2'd1;  // right
                        end else begin
                            direction <= 2'd0;  // up
                        end
                    end else begin
                        if (r_reg == h_reg - 16'd1) begin
                            direction <= 2'd3;  // left
                        end else begin
                            direction <= 2'd2;  // down
                        end
                    end
                    state <= CALC_NEW_POS;
                end
                
                CALC_NEW_POS: begin
                    // Calculate new position based on direction
                    case (direction)
                        2'd0: begin  // up
                            new_r <= r_reg - 32'd1;
                            new_c <= c_reg;
                        end
                        2'd1: begin  // right
                            new_r <= r_reg;
                            new_c <= c_reg + 32'd1;
                        end
                        2'd2: begin  // down
                            new_r <= r_reg + 32'd1;
                            new_c <= c_reg;
                        end
                        2'd3: begin  // left
                            new_r <= r_reg;
                            new_c <= c_reg - 32'd1;
                        end
                        default: begin
                            new_r <= r_reg;
                            new_c <= c_reg;
                        end
                    endcase
                    state <= CALC_RESULT;
                end
                
                CALC_RESULT: begin
                    // Calculate result = new_r - new_c
                    step_result <= new_r - new_c;
                    state <= FINISH;
                end
                
                FINISH: begin
                    result <= step_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule