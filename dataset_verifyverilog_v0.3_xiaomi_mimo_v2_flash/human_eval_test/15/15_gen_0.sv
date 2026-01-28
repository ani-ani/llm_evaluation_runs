module string_sequence (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [7:0] byte_out,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE_NUM = 3'd1;
    localparam [2:0] OUTPUT_SPACE = 3'd2;
    localparam [2:0] FINISHED = 3'd3;

    reg [2:0] state;
    reg [3:0] current_num;
    reg output_space_phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            byte_out <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            current_num <= 4'd0;
            output_space_phase <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    current_num <= 4'd0;
                    output_space_phase <= 1'b0;
                    if (start) begin
                        state <= GENERATE_NUM;
                    end
                end

                GENERATE_NUM: begin
                    byte_out <= 8'h30 + {4'd0, current_num}; // ASCII '0' + number
                    valid <= 1'b1;
                    done <= 1'b0;
                    
                    // After outputting digit, decide next state
                    if (current_num == n) begin
                        // Last number - go to finished
                        state <= FINISHED;
                        output_space_phase <= 1'b0;
                    end else begin
                        // Not last - output space next
                        state <= OUTPUT_SPACE;
                        output_space_phase <= 1'b0;
                    end
                end

                OUTPUT_SPACE: begin
                    if (!output_space_phase) begin
                        // Output space
                        byte_out <= 8'h20;
                        valid <= 1'b1;
                        done <= 1'b0;
                        output_space_phase <= 1'b1;
                        // Stay in this state for next cycle
                    end else begin
                        // Second cycle: increment number and go back to generate
                        valid <= 1'b0;
                        current_num <= current_num + 4'd1;
                        output_space_phase <= 1'b0;
                        state <= GENERATE_NUM;
                    end
                end

                FINISHED: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule