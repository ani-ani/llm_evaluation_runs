module rescale_unit_range (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire arr_valid,
    input wire [15:0] arr_in [7:0],
    input wire [2:0] len,
    output reg result_valid,
    output reg [15:0] arr_out [7:0],
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] RESET_MINMAX  = 4'd1;
    localparam [3:0] FIND_MIN      = 4'd2;
    localparam [3:0] FIND_MAX      = 4'd3;
    localparam [3:0] COMPUTE_SCALE = 4'd4;
    localparam [3:0] DIVIDE_START  = 4'd5;
    localparam [3:0] DIVIDE_WAIT   = 4'd6;
    localparam [3:0] OUTPUT_STATE  = 4'd7;
    localparam [3:0] FINISH        = 4'd8;

    reg [3:0] state, next_state;
    reg [2:0] idx;
    reg [2:0] div_idx;
    reg [15:0] min_val, max_val;
    reg [15:0] scale;
    reg [15:0] min_reg, max_reg;
    reg [15:0] arr_reg [7:0];
    reg [15:0] temp_result [7:0];
    reg [15:0] numerator;
    reg [15:0] divisor;
    reg [31:0] division_result;
    reg [2:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd100;

    // For division: (value - min) * 65536 / scale
    // 65536 = 2^16, so we shift left 16 bits for Q8.8 -> Q24.40 conversion
    wire signed [31:0] div_temp;
    wire signed [15:0] quotient;
    assign div_temp = {16'h0000, numerator} << 16;  // 16-bit to 32-bit, left shift 16
    
    // Combinational division (Q8.8 / Q8.8 = Q0.8, but we want Q8.8 result)
    // Actually: (value-min) is Q8.8, scale is Q8.8
    // To get result in Q8.8: ((value-min) * 256) / scale
    // Because (value-min)/scale gives Q0.8, multiply by 256 gives Q8.8
    wire [31:0] div_numerator_q8;
    wire [15:0] div_quotient_q8;
    assign div_numerator_q8 = {16'd0, numerator};  // 32-bit: [31:16]=0, [15:0]=numerator
    assign div_quotient_q8 = (divisor == 16'd0) ? 16'd0 : div_numerator_q8[15:0] / divisor;

    integer i;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            done <= 1'b0;
            idx <= 3'd0;
            div_idx <= 3'd0;
            min_val <= 16'h7FFF;  // Max positive in signed 16-bit
            max_val <= 16'h8000;  // Min negative in signed 16-bit
            min_reg <= 16'd0;
            max_reg <= 16'd0;
            scale <= 16'd0;
            numerator <= 16'd0;
            divisor <= 16'd0;
            cycle_count <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                arr_reg[i] <= 16'd0;
                temp_result[i] <= 16'd0;
                arr_out[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    idx <= 3'd0;
                    div_idx <= 3'd0;
                    cycle_count <= 3'd0;
                    if (arr_valid && start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            arr_reg[i] <= arr_in[i];
                        end
                    end
                end
                
                RESET_MINMAX: begin
                    min_val <= 16'h7FFF;
                    max_val <= 16'h8000;
                    idx <= 3'd0;
                end
                
                FIND_MIN: begin
                    if (idx < len) begin
                        if (arr_reg[idx] < min_val) begin
                            min_val <= arr_reg[idx];
                        end
                        idx <= idx + 3'd1;
                    end
                end
                
                FIND_MAX: begin
                    if (idx < len) begin
                        if (arr_reg[idx] > max_val) begin
                            max_val <= arr_reg[idx];
                        end
                        idx <= idx + 3'd1;
                    end
                end
                
                COMPUTE_SCALE: begin
                    min_reg <= min_val;
                    max_reg <= max_val;
                    if (max_val < min_val) begin
                        // Swap if reverse range
                        min_reg <= max_val;
                        max_reg <= min_val;
                    end
                    scale <= max_val - min_val;  // 16-bit subtraction
                end
                
                DIVIDE_START: begin
                    div_idx <= 3'd0;
                    numerator <= arr_reg[0] - min_reg;
                    divisor <= scale;
                end
                
                DIVIDE_WAIT: begin
                    // Perform division
                    if (divisor == 16'd0) begin
                        temp_result[div_idx] <= 16'd0;
                    end else begin
                        // (value - min) * 256 / scale
                        // numerator is Q8.8, multiplying by 256 converts to Q16.8
                        // dividing by scale (Q8.8) gives Q8.8
                        // Use combinational division result
                        temp_result[div_idx] <= div_quotient_q8;
                    end
                    
                    div_idx <= div_idx + 3'd1;
                    if (div_idx < (len - 3'd1)) begin
                        numerator <= arr_reg[div_idx + 3'd1] - min_reg;
                    end
                end
                
                OUTPUT_STATE: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < len) begin
                            arr_out[i] <= temp_result[i];
                        end else begin
                            arr_out[i] <= 16'd0;
                        end
                    end
                    result_valid <= 1'b1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                end
            endcase
            
            cycle_count <= cycle_count + 3'd1;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (arr_valid && start) begin
                    next_state = RESET_MINMAX;
                end else begin
                    next_state = IDLE;
                end
            end
            
            RESET_MINMAX: begin
                next_state = FIND_MIN;
            end
            
            FIND_MIN: begin
                if (idx < len) begin
                    next_state = FIND_MIN;
                end else begin
                    next_state = FIND_MAX;
                end
            end
            
            FIND_MAX: begin
                if (idx < len) begin
                    next_state = FIND_MAX;
                end else begin
                    next_state = COMPUTE_SCALE;
                end
            end
            
            COMPUTE_SCALE: begin
                next_state = DIVIDE_START;
            end
            
            DIVIDE_START: begin
                next_state = DIVIDE_WAIT;
            end
            
            DIVIDE_WAIT: begin
                if (div_idx < len) begin
                    next_state = DIVIDE_WAIT;
                end else begin
                    next_state = OUTPUT_STATE;
                end
            end
            
            OUTPUT_STATE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Timeout protection
        if (cycle_count >= MAX_CYCLES) begin
            next_state = IDLE;
        end
    end

endmodule