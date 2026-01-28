module rain_cycler #(
    parameter integer T = 16,
    parameter integer DATA_WIDTH = 24,
    parameter integer RAIN_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] c,
    input wire [DATA_WIDTH-1:0] d,
    input wire [RAIN_WIDTH-1:0] rain [0:15],
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

    // State machine definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CUM_SUM    = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] COMPARE    = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Internal registers and wires
    reg [2:0] state, next_state;
    reg [3:0] idx;                // Index for rain array (0-15)
    reg [3:0] dt;                 // Travel duration counter (1-T)
    reg [31:0] rain_cum [0:16];  // Cumulative sum array (0-T)
    reg [DATA_WIDTH-1:0] min_wet;
    reg [31:0] current_wet;       // 32-bit for intermediate calculations
    reg [31:0] temp_val;
    reg [1:0] compute_step;       // Track steps in computation
    reg [3:0] cycle_counter;      // Cycle counter for operations

    // Fixed-point constants
    localparam [15:0] SIXTY_SQUARED_Q16 = 16'd3600;  // 60^2 in Q0.16

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 24'd0;
            min_wet <= 24'd0;
            idx <= 4'd0;
            dt <= 4'd0;
            compute_step <= 2'd0;
            cycle_counter <= 4'd0;
            current_wet <= 32'd0;
            temp_val <= 32'd0;
            // Initialize rain_cum array
            for (integer i = 0; i < 17; i = i + 1) begin
                rain_cum[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 4'd0;
                    dt <= 4'd0;
                    compute_step <= 2'd0;
                    cycle_counter <= 4'd0;
                    min_wet <= 24'hFFFFFF;  // Initialize to max
                    current_wet <= 32'd0;
                    temp_val <= 32'd0;
                    // Reset cumulative sum array
                    for (integer i = 0; i < 17; i = i + 1) begin
                        rain_cum[i] <= 32'd0;
                    end
                end
                
                CUM_SUM: begin
                    if (idx <= 4'd15) begin
                        if (idx == 4'd0) begin
                            rain_cum[idx] <= 32'd0;
                        end else begin
                            rain_cum[idx] <= rain_cum[idx-1] + {24'd0, rain[idx-1]};
                        end
                        idx <= idx + 4'd1;
                    end
                end
                
                COMPUTE: begin
                    case (compute_step)
                        2'd0: begin
                            // Step 0: Calculate rain wetness
                            // rain_cum[dt] - rain_cum[0], but rain_cum[0] is always 0
                            temp_val <= rain_cum[dt];
                            compute_step <= 2'd1;
                        end
                        2'd1: begin
                            // Step 1: Calculate (60*d)^2 / dt
                            // First calculate 60*d (d is Q8.8, so multiply by 60)
                            // d * 60 = d * 60 (result needs more bits)
                            temp_val <= temp_val + 32'd1;  // Placeholder
                            // Actually: temp_val = c * (60*d)^2 / dt
                            // (60*d)^2 = (d*60)^2, d is Q8.8, so result is Q16.16
                            // Multiply d by 60: result is Q8.8 * Q6.0 = Q14.8
                            // Then square: (Q14.8)^2 = Q28.16
                            // Then multiply by c (Q8.8): Q28.16 * Q8.8 = Q36.24
                            // Then divide by dt (Q8.8): Q36.24 / Q8.8 = Q28.16
                            // For Q8.8 final result, shift right 8 bits
                            // Simplified approach for fixed-point:
                            // (60*d)^2 * c / dt, with proper shifting
                            temp_val <= (d * 60) * (d * 60);  // (60*d)^2
                            compute_step <= 2'd2;
                        end
                        2'd2: begin
                            // Multiply by c
                            temp_val <= temp_val * c;
                            compute_step <= 2'd3;
                        end
                        2'd3: begin
                            // Divide by dt (shift right 8 for Q8.8 division)
                            // division by dt: we need to shift right by 8 to normalize
                            // temp_val is in Q36.24, divide by dt (Q8.8) = Q28.16
                            // Shift right 8 to get Q20.8
                            current_wet <= temp_val >> 8;  // rain wetness already in temp_val from step 0
                            // Actually, we need to add rain wetness first
                            // Let me recalculate properly
                            current_wet <= rain_cum[dt] + (temp_val >> 8);
                            compute_step <= 2'd0;
                            dt <= dt + 4'd1;
                            cycle_counter <= 4'd0;
                        end
                        default: compute_step <= 2'd0;
                    endcase
                end
                
                COMPARE: begin
                    if (current_wet[31:8] < min_wet) begin
                        min_wet <= current_wet[31:8];
                    end
                end
                
                FINISH: begin
                    result <= min_wet;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CUM_SUM;
                else next_state = IDLE;
            end
            
            CUM_SUM: begin
                if (idx > 4'd15) next_state = COMPUTE;
                else next_state = CUM_SUM;
            end
            
            COMPUTE: begin
                if (compute_step == 2'd3) next_state = COMPARE;
                else next_state = COMPUTE;
            end
            
            COMPARE: begin
                if (dt > 4'd15) next_state = FINISH;
                else next_state = COMPUTE;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule