module encrypt(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] len,
    output reg [7:0] char_out,
    output reg out_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] READ    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] FINISH  = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [7:0] current_char;
    reg [7:0] encrypted_char;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            current_char <= 8'd0;
            encrypted_char <= 8'd0;
            char_out <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        case (state)
            IDLE: begin
                out_valid = 1'b0;
                done = 1'b0;
                if (start) begin
                    next_state = READ;
                    index = 4'd0;
                end else begin
                    next_state = IDLE;
                end
            end

            READ: begin
                out_valid = 1'b0;
                done = 1'b0;
                if (index < len) begin
                    current_char = char_in;
                    next_state = PROCESS;
                end else begin
                    next_state = FINISH;
                end
            end

            PROCESS: begin
                out_valid = 1'b0;
                done = 1'b0;
                // Encryption logic
                if (current_char >= 8'h61 && current_char <= 8'h7A) begin
                    // Lowercase letters
                    if (current_char + 4 > 8'h7A) begin
                        encrypted_char = current_char + 4 - 26;
                    end else begin
                        encrypted_char = current_char + 4;
                    end
                end else if (current_char >= 8'h41 && current_char <= 8'h5A) begin
                    // Uppercase letters
                    if (current_char + 4 > 8'h5A) begin
                        encrypted_char = current_char + 4 - 26;
                    end else begin
                        encrypted_char = current_char + 4;
                    end
                end else begin
                    // Non-alphabetic characters
                    encrypted_char = current_char;
                end
                next_state = OUTPUT;
            end

            OUTPUT: begin
                out_valid = 1'b1;
                done = 1'b0;
                char_out = encrypted_char;
                next_state = READ;
                index = index + 1;
            end

            FINISH: begin
                out_valid = 1'b0;
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                out_valid = 1'b0;
                done = 1'b0;
                next_state = IDLE;
            end
        endcase
    end

endmodule