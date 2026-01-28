module StringGenerator(
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    input [7:0] k_in,
    output reg [127:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] GENERATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [15:0] n_reg, k_reg;
    reg [15:0] pos_counter;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg [7:0] char_index;
    reg [7:0] cycle_count;
    reg error_flag;
    reg [7:0] i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 16'd0;
            k_reg <= 8'd0;
            pos_counter <= 16'd0;
            current_char <= 8'd0;
            next_char <= 8'd0;
            char_index <= 8'd0;
            cycle_count <= 8'd0;
            error_flag <= 1'b0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 128'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        next_state <= CHECK;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK: begin
                    // Check for error conditions
                    if (k_reg > n_reg || (k_reg == 1 && n_reg > 1) || k_reg > 16) begin
                        error_flag <= 1'b1;
                        next_state <= GENERATE;
                    end else begin
                        error_flag <= 1'b0;
                        next_state <= GENERATE;
                    end
                    pos_counter <= 16'd0;
                    char_index <= 8'd0;
                    cycle_count <= 8'd0;
                end

                GENERATE: begin
                    if (error_flag) begin
                        // Set all characters to 0xFF
                        for (i = 0; i < 16; i = i + 1) begin
                            result[(i*8)+7:i*8] <= 8'hFF;
                        end
                        valid <= 1'b1;
                        next_state <= DONE_STATE;
                    end else if (pos_counter < n_reg) begin
                        // Generate characters
                        if (pos_counter < n_reg - k_reg + 2) begin
                            // Alternating 'a' and 'b'
                            if (pos_counter % 2 == 0) begin
                                current_char <= 8'd0; // 'a'
                            end else begin
                                current_char <= 8'd1; // 'b'
                            end
                        end else begin
                            // Remaining characters: 'c', 'd', etc.
                            current_char <= char_index + 2;
                            char_index <= char_index + 1;
                        end
                        // Pack into result
                        if (pos_counter < 16) begin
                            result[(pos_counter*8)+7:pos_counter*8] <= current_char;
                        end
                        pos_counter <= pos_counter + 1;
                        cycle_count <= cycle_count + 1;
                        if (cycle_count >= 255) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= GENERATE;
                        end
                    end else begin
                        valid <= 1'b1;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule