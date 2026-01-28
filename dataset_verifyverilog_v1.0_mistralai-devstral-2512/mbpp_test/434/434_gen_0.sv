module pattern_detector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str_data,
    input wire [3:0] str_len,
    output reg match_found,
    output reg done
);

    // State definitions
    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_SCAN  = 2'd1;
    localparam [1:0] S_DONE  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg found_a;
    reg [7:0] current_char;

    // ASCII values
    localparam [7:0] ASCII_a = 8'h61;
    localparam [7:0] ASCII_b = 8'h62;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            index <= 4'd0;
            found_a <= 1'b0;
            match_found <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= S_SCAN;
                        index <= 4'd0;
                        found_a <= 1'b0;
                        match_found <= 1'b0;
                    end
                end

                S_SCAN: begin
                    // Extract current character
                    current_char = str_data[index*8 +: 8];

                    // Check for pattern
                    if (current_char == ASCII_a) begin
                        found_a <= 1'b1;
                    end else if (current_char == ASCII_b && found_a) begin
                        match_found <= 1'b1;
                    end else if (current_char != ASCII_a && current_char != ASCII_b) begin
                        found_a <= 1'b0;
                    end

                    // Increment index
                    if (index < str_len - 1) begin
                        index <= index + 4'd1;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule