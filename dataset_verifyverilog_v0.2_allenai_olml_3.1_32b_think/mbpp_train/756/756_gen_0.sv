module pattern_matcher(
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0][7:0] str_in,
    output reg match,
    output reg done);

typedef enum {IDLE, SCANNING, MATCH_FOUND, DONE} state_t;
state_t state;

reg [3:0] index;
reg match_reg;
reg [1:0] done_counter;

initial begin
    state = IDLE;
    match_reg = 1'b0;
    done_counter = 2'b10; // invalid
    index = 0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        match_reg <= 1'b0;
        done_counter <= 2'b10;
        index <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= SCANNING;
                    index <= 0;
                    match_reg <= 1'b0;
                end else begin
                    state <= IDLE;
                end
            end
            SCANNING: begin
                if (index < 8) begin
                    // Check for 'a' followed by 'b'
                    if (str_in[index] == 8'h61) begin // 'a'
                        if (index < 7 && str_in[index + 1] == 8'h62) begin // 'b'
                            match_reg <= match_reg | 1'b1;
                        end
                    end
                    index <= index + 1;
                    if (index < 8) state <= SCANNING;
                    else begin // Finished scanning
                        state <= DONE;
                        done_counter <= 1; // Delay for 2 cycles (count 1 and 0)
                    end
                end
            end
            MATCH_FOUND: begin
                // This state is unused but required
                state <= DONE;
                done_counter <= 1; // Reset delay
            end
            DONE: begin
                if (done_counter == 0) begin
                    done_reg <= 1'b1;
                end else begin
                    done_counter <= done_counter - 1;
                    done_reg <= 1'b0;
                end
                state <= DONE;
            end
        endcase
    end
end

// Outputs
assign match = match_reg;
assign done = done_reg;

endmodule