module date_validator (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input chars_done,
    output reg result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RECEIVING = 3'd1;
    localparam [2:0] CHECK_FORMAT = 3'd2;
    localparam [2:0] PARSE_MONTH = 3'd3;
    localparam [2:0] PARSE_DAY = 3'd4;
    localparam [2:0] PARSE_YEAR = 3'd5;
    localparam [2:0] VALIDATE = 3'd6;
    localparam [2:0] COMPLETE = 3'd7;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Character buffer
    reg [7:0] chars [0:9];
    
    // Counters and flags
    reg [3:0] char_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    // Parsed values
    reg [7:0] month;
    reg [7:0] day;
    reg [15:0] year;
    
    // Error flags
    reg format_error;
    reg month_error;
    reg day_error;
    reg year_error;
    
    // Integer for loops
    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? RECEIVING : IDLE;
            RECEIVING: next_state = (chars_done) ? CHECK_FORMAT : RECEIVING;
            CHECK_FORMAT: next_state = (format_error) ? COMPLETE : PARSE_MONTH;
            PARSE_MONTH: next_state = PARSE_DAY;
            PARSE_DAY: next_state = PARSE_YEAR;
            PARSE_YEAR: next_state = VALIDATE;
            VALIDATE: next_state = COMPLETE;
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            char_idx <= 4'd0;
            cycle_count <= 8'd0;
            month <= 8'd0;
            day <= 8'd0;
            year <= 16'd0;
            format_error <= 1'b0;
            month_error <= 1'b0;
            day_error <= 1'b0;
            year_error <= 1'b0;
            // Clear char buffer
            for (i = 0; i < 10; i = i + 1) begin
                chars[i] <= 8'd0;
            end
        end else begin
            // Increment cycle counter
            cycle_count <= cycle_count + 8'd1;
            
            // Default outputs
            done <= 1'b0;
            error <= 1'b0;
            
            // State transitions
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    result <= 1'b0;
                    char_idx <= 4'd0;
                    cycle_count <= 8'd0;
                    format_error <= 1'b0;
                    month_error <= 1'b0;
                    day_error <= 1'b0;
                    year_error <= 1'b0;
                    // Clear buffer
                    for (i = 0; i < 10; i = i + 1) begin
                        chars[i] <= 8'd0;
                    end
                end
                
                RECEIVING: begin
                    if (char_valid && char_idx < 10) begin
                        chars[char_idx] <= char_in;
                        char_idx <= char_idx + 4'd1;
                    end
                    
                    if (chars_done) begin
                        char_idx <= 4'd0;
                    end
                end
                
                CHECK_FORMAT: begin
                    format_error <= 1'b0;
                    
                    // Check hyphens at positions 2 and 5
                    if (chars[2] != 8'h2D || chars[5] != 8'h2D) begin
                        format_error <= 1'b1;
                    end
                    
                    // Check all digits (except hyphens)
                    if (!((chars[0] >= 8'h30 && chars[0] <= 8'h39) &&
                          (chars[1] >= 8'h30 && chars[1] <= 8'h39) &&
                          (chars[3] >= 8'h30 && chars[3] <= 8'h39) &&
                          (chars[4] >= 8'h30 && chars[4] <= 8'h39) &&
                          (chars[6] >= 8'h30 && chars[6] <= 8'h39) &&
                          (chars[7] >= 8'h30 && chars[7] <= 8'h39) &&
                          (chars[8] >= 8'h30 && chars[8] <= 8'h39) &&
                          (chars[9] >= 8'h30 && chars[9] <= 8'h39))) begin
                        format_error <= 1'b1;
                    end
                end
                
                PARSE_MONTH: begin
                    // Convert ASCII to integer (mm)
                    month <= (chars[0] - 8'h30) * 8'd10 + (chars[1] - 8'h30);
                end
                
                PARSE_DAY: begin
                    // Convert ASCII to integer (dd)
                    day <= (chars[3] - 8'h30) * 8'd10 + (chars[4] - 8'h30);
                end
                
                PARSE_YEAR: begin
                    // Convert ASCII to integer (yyyy)
                    year <= ((chars[6] - 8'h30) * 16'd1000) +
                            ((chars[7] - 8'h30) * 16'd100) +
                            ((chars[8] - 8'h30) * 16'd10) +
                            (chars[9] - 8'h30);
                end
                
                VALIDATE: begin
                    // Validate month (1-12)
                    if (month < 8'd1 || month > 8'd12) begin
                        month_error <= 1'b1;
                    end
                    
                    // Validate day based on month
                    day_error <= 1'b0;
                    case (month)
                        8'd1, 8'd3, 8'd5, 8'd7, 8'd8, 8'd10, 8'd12: begin
                            if (day < 8'd1 || day > 8'd31) begin
                                day_error <= 1'b1;
                            end
                        end
                        8'd4, 8'd6, 8'd9, 8'd11: begin
                            if (day < 8'd1 || day > 8'd30) begin
                                day_error <= 1'b1;
                            end
                        end
                        8'd2: begin
                            if (day < 8'd1 || day > 8'd29) begin
                                day_error <= 1'b1;
                            end
                        end
                        default: day_error <= 1'b1;
                    endcase
                    
                    // Validate year (1000-9999)
                    if (year < 16'd1000 || year > 16'd9999) begin
                        year_error <= 1'b1;
                    end
                end
                
                COMPLETE: begin
                    // Check all error conditions
                    if (format_error || month_error || day_error || year_error) begin
                        result <= 1'b0;
                        error <= 1'b1;
                    end else begin
                        result <= 1'b1;
                        error <= 1'b0;
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // State transition
            state <= next_state;
        end
    end

endmodule