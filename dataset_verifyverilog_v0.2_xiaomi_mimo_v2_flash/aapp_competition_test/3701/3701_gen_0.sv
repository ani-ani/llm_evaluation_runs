module binary_string_cost (
    input clk,
    input rst_n,
    input start,
    input [7:0] str_len,
    input [7:0] char_in,
    input valid_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] X = 10;
    localparam [31:0] Y = 1;
    localparam LATENCY = 10;

    // State Encoding
    localparam [1:0] IDLE      = 2'b00;
    localparam [1:0] READING   = 2'b01;
    localparam [1:0] COMPUTING = 2'b10;
    localparam [1:0] DONE      = 2'b11;

    // Registers
    reg [1:0] current_state, next_state;
    reg [7:0] char_cnt;
    reg [7:0] groups;
    reg prev_char;
    reg [3:0] wait_cnt; // Counts 10 cycles max (0-9)

    // State Transition and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            char_cnt <= 0;
            groups <= 0;
            prev_char <= 0;
            wait_cnt <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        current_state <= READING;
                        char_cnt <= 0;
                        groups <= 0;
                        prev_char <= 1; // Assume initial segment starts if first char is 0
                    end
                end

                READING: begin
                    if (valid_in) begin
                        char_cnt <= char_cnt + 1;
                        // Detect start of a '0' segment (transition 1->0 or start with 0)
                        if (char_in == 0) begin
                            if (prev_char == 1) begin
                                groups <= groups + 1;
                            end
                        end
                        prev_char <= char_in;
                    end
                    
                    // Check if we have received all characters
                    // Note: str_len is max 8, so char_cnt will wrap or max out. 
                    // Using explicit comparison for safety.
                    if (char_cnt == str_len && str_len != 0) begin
                        current_state <= COMPUTING;
                        wait_cnt <= 0;
                    end
                    // Handle edge case: if str_len is 0, go directly to computing/waiting
                    if (str_len == 0 && start) begin
                         current_state <= COMPUTING;
                         wait_cnt <= 0;
                    end
                    // Fallback timeout if valid_in is stuck low or len mismatch to prevent lockup
                    // (Not strictly required by prompt but good practice, omitted here for strict adherence)
                end

                COMPUTING: begin
                    // Calculate Result
                    if (groups == 0) begin
                        result <= 0;
                    end else begin
                        if (X <= Y) begin
                            result <= (groups - 1) * X + Y;
                        end else begin
                            result <= groups * Y;
                        end
                    end
                    
                    // Latency State Waiting
                    if (wait_cnt < LATENCY - 1) begin // 9 cycles in computing + 1 in IDLE/DONE = 10 total from start, or 10 cycles in state. Prompt says 10 clock cycles after start. Usually implies 10 cycles total latency. Let's wait 9 more cycles here.
                        wait_cnt <= wait_cnt + 1;
                    end else begin
                        current_state <= DONE;
                        done <= 1;
                    end
                end

                DONE: begin
                    done <= 0;
                    current_state <= IDLE;
                end
            endcase
        end
    end

endmodule