module is_undulating (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] num,
    output reg is_undulating,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CONVERT   = 2'd1;
    localparam [1:0] CHECK     = 2'd2;
    localparam [1:0] FINISH    = 2'd3;
    
    localparam NUM_DIGITS = 10;
    localparam [3:0] MAX_DIGITS = 4'd10;
    
    // Registers
    reg [1:0] state, next_state;
    reg [31:0] num_reg;
    reg [3:0] digit_array [0:9]; // 10 digits, 4 bits each (0-9)
    reg [3:0] digit_index;
    reg [3:0] temp_num;
    reg [3:0] len;
    reg [3:0] check_index;
    reg pattern_valid;
    reg [1:0] cycle_count;
    
    integer i;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_undulating <= 1'b0;
            done <= 1'b0;
            num_reg <= 32'd0;
            digit_index <= 4'd0;
            temp_num <= 4'd0;
            len <= 4'd0;
            check_index <= 4'd0;
            pattern_valid <= 1'b0;
            cycle_count <= 2'd0;
            // Initialize digit array to avoid X values
            for (i = 0; i < 10; i = i + 1) begin
                digit_array[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    is_undulating <= 1'b0;
                    digit_index <= 4'd0;
                    check_index <= 4'd0;
                    pattern_valid <= 1'b1; // Start assuming valid
                    cycle_count <= 2'd0;
                    
                    if (start) begin
                        num_reg <= num;
                        state <= CONVERT;
                    end
                end
                
                CONVERT: begin
                    // First cycle: prepare for conversion
                    if (cycle_count == 2'd0) begin
                        // Check if num is 0
                        if (num_reg == 32'd0) begin
                            len <= 4'd1;
                            digit_array[0] <= 4'd0;
                            state <= CHECK;
                            cycle_count <= 2'd0;
                        end else begin
                            temp_num <= num_reg[3:0];
                            digit_index <= 4'd0;
                            cycle_count <= 2'd1;
                        end
                    end else begin
                        // Second+ cycles: convert digits
                        if (digit_index < MAX_DIGITS && num_reg > 0) begin
                            // Divide by 10 using repeated subtraction
                            if (num_reg >= 32'd10) begin
                                num_reg <= num_reg - 32'd10;
                                temp_num <= temp_num + 4'd1;
                            end else begin
                                // Store quotient and remainder
                                digit_array[digit_index] <= temp_num;
                                num_reg <= num_reg >> 4; // This doesn't work for division
                                // Use proper division
                                num_reg <= num_reg / 32'd10;
                                digit_index <= digit_index + 4'd1;
                                len <= digit_index + 4'd1;
                                // Reset temp_num for next digit
                                temp_num <= num_reg % 32'd10;
                                cycle_count <= 2'd0;
                                
                                if (num_reg < 32'd10) begin
                                    state <= CHECK;
                                    // Store the last digit
                                    digit_array[digit_index + 4'd1] <= num_reg % 32'd10;
                                end
                            end
                        end else begin
                            state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    // Check pattern for lengths <= 2
                    if (len <= 4'd2) begin
                        pattern_valid <= 1'b0;
                        state <= FINISH;
                    end else if (check_index < len && check_index >= 4'd2) begin
                        if (digit_array[check_index] != digit_array[check_index - 2'd2]) begin
                            pattern_valid <= 1'b0;
                        end
                        check_index <= check_index + 4'd1;
                    end else begin
                        // Done checking
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    is_undulating <= pattern_valid;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule