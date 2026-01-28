module NameFilter(
    input clk,
    input rst_n,
    input start,
    input [7:0] names [0:5][7:0],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_NAME = 3'd1;
    localparam [2:0] VALIDATE = 3'd2;
    localparam [2:0] SUM = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] name_idx;
    reg [3:0] char_idx;
    reg [15:0] temp_sum;
    reg [15:0] name_len;
    reg is_valid;
    reg is_uppercase;
    reg is_lowercase_or_null;
    
    // Control signals
    reg [7:0] current_char;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            name_idx <= 4'd0;
            char_idx <= 4'd0;
            temp_sum <= 16'd0;
            name_len <= 16'd0;
            is_valid <= 1'b0;
            current_char <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    temp_sum <= 16'd0;
                    name_idx <= 4'd0;
                    char_idx <= 4'd0;
                end
                CHECK_NAME: begin
                    char_idx <= 4'd0;
                    name_len <= 16'd0;
                    is_valid <= 1'b1;
                    current_char <= names[name_idx][0];
                end
                VALIDATE: begin
                    // Check first character for uppercase
                    if (char_idx == 4'd0) begin
                        is_uppercase <= (current_char >= 8'd65 && current_char <= 8'd90);
                        if (!(current_char >= 8'd65 && current_char <= 8'd90)) begin
                            is_valid <= 1'b0;
                        end
                        // Count length for first char if valid
                        if (current_char != 8'd0) begin
                            name_len <= name_len + 16'd1;
                        end
                    end else begin
                        // Check subsequent characters for lowercase or null
                        is_lowercase_or_null <= (current_char >= 8'd97 && current_char <= 8'd122) || (current_char == 8'd0);
                        if (!((current_char >= 8'd97 && current_char <= 8'd122) || (current_char == 8'd0))) begin
                            is_valid <= 1'b0;
                        end
                        // Count length if not null
                        if (current_char != 8'd0 && char_idx < 4'd8) begin
                            name_len <= name_len + 16'd1;
                        end
                    end
                    // Prepare next character
                    if (char_idx < 4'd7) begin
                        current_char <= names[name_idx][char_idx + 1];
                    end
                end
                SUM: begin
                    if (is_valid && (name_len > 16'd0)) begin
                        temp_sum <= temp_sum + name_len;
                    end
                end
                COMPLETE: begin
                    result <= temp_sum;
                    done <= 1'b1;
                    name_idx <= 4'd0;
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
                if (start) begin
                    next_state = CHECK_NAME;
                end else begin
                    next_state = IDLE;
                end
            end
            CHECK_NAME: begin
                if (name_idx < len) begin
                    next_state = VALIDATE;
                end else begin
                    next_state = COMPLETE;
                end
            end
            VALIDATE: begin
                if (char_idx == 4'd7) begin
                    next_state = SUM;
                end else begin
                    next_state = VALIDATE;
                end
            end
            SUM: begin
                next_state = CHECK_NAME;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            name_idx <= 4'd0;
            char_idx <= 4'd0;
        end else begin
            case (state)
                CHECK_NAME: begin
                    name_idx <= name_idx + 4'd1;
                    char_idx <= 4'd0;
                end
                VALIDATE: begin
                    char_idx <= char_idx + 4'd1;
                end
                default: begin
                end
            endcase
        end
    end
    
endmodule