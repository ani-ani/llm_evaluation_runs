module z_detector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],
    input wire [4:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg in_word;
    reg found_z;
    reg [7:0] current_char;

    // Character classification
    wire is_alphanumeric;
    wire is_z;

    assign current_char = str[index];
    assign is_alphanumeric = (current_char >= 8'd48 && current_char <= 8'd57) ||  // 0-9
                              (current_char >= 8'd65 && current_char <= 8'd90) ||  // A-Z
                              (current_char >= 8'd97 && current_char <= 8'd122); // a-z
    assign is_z = (current_char == 8'd122);

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            in_word <= 1'b0;
            found_z <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= SCAN;
                        index <= 4'd0;
                        in_word <= 1'b0;
                        found_z <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    if (index < len) begin
                        // Process current character
                        if (is_alphanumeric) begin
                            if (!in_word) begin
                                in_word <= 1'b1;
                            end
                            if (is_z) begin
                                found_z <= 1'b1;
                            end
                        end else begin
                            if (in_word) begin
                                in_word <= 1'b0;
                            end
                        end

                        // Move to next character
                        index <= index + 4'd1;
                        next_state <= SCAN;
                    end else begin
                        // End of string
                        if (in_word) begin
                            in_word <= 1'b0;
                        end
                        result <= found_z;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule