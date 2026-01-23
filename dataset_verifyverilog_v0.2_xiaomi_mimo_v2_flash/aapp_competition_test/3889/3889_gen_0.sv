module doggo_standardization (
    input clk,
    input rst_n,
    input start,
    input [4:0] char_in,
    input char_valid,
    output reg result,
    output reg done
);

    // Parameters
    parameter MAX_LEN = 16;
    parameter CHAR_WIDTH = 5;

    // States
    localparam IDLE = 2'b00;
    localparam RECV = 2'b01;
    localparam CHECK = 2'b10;
    localparam DONE = 2'b11;

    // Registers
    reg [1:0] state, next_state;
    reg [4:0] count_reg [0:25]; // 26 counters, 5-bit width
    reg [4:0] len_cnt;           // Input counter (0 to 16)
    reg result_reg;
    integer i;
    reg flag_ge2; // Flag to check if any color count >= 2

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic (Moore style logic block)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = RECV;
            end
            RECV: begin
                // Check if we have received MAX_LEN characters
                if (len_cnt == MAX_LEN)
                    next_state = CHECK;
            end
            CHECK: begin
                // Processing takes 1 cycle (based on "18 cycles after start" requirement)
                next_state = DONE;
            end
            DONE: begin
                // Stay here until reset or new start (implicit by transition logic below)
                // To allow restart, we transition to IDLE on start
                if (start)
                    next_state = RECV;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Data processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset counters and flags
            for (i = 0; i < 26; i = i + 1) begin
                count_reg[i] <= 5'b0;
            end
            len_cnt <= 5'b0;
            result <= 1'b0;
            done <= 1'b0;
            result_reg <= 1'b0;
            flag_ge2 <= 1'b0;
        end else begin
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Clear counters and counters on start
                        for (i = 0; i < 26; i = i + 1) begin
                            count_reg[i] <= 5'b0;
                        end
                        len_cnt <= 5'b0;
                        result_reg <= 1'b0;
                        flag_ge2 <= 1'b0;
                    end
                end

                RECV: begin
                    if (char_valid) begin
                        // Increment counter for the valid character
                        // Ensure char_in is within range 0-25 to avoid index out of bounds
                        if (char_in < 26)
                            count_reg[char_in] <= count_reg[char_in] + 1'b1;
                        
                        // Increment length counter
                        len_cnt <= len_cnt + 1'b1;
                    end
                end

                CHECK: begin
                    // Determine result in this single cycle
                    // Logic: If n=1 (len_cnt==1) -> Yes
                    // If any count >= 2 -> Yes
                    // Otherwise -> No
                    
                    // Check condition 1: n=1
                    if (len_cnt == 1) begin
                        result_reg <= 1'b1;
                    end else begin
                        // Check condition 2: any count >= 2
                        flag_ge2 = 1'b0;
                        for (i = 0; i < 26; i = i + 1) begin
                            if (count_reg[i] >= 2) begin
                                flag_ge2 = 1'b1;
                            end
                        end
                        
                        if (flag_ge2)
                            result_reg <= 1'b1;
                        else
                            result_reg <= 1'b0;
                    end
                end

                DONE: begin
                    // Latch result to output
                    result <= result_reg;
                    done <= 1'b1;
                    
                    // If start is asserted again, clear counters immediately for next run
                    if (start) begin
                        done <= 1'b0;
                        for (i = 0; i < 26; i = i + 1) begin
                            count_reg[i] <= 5'b0;
                        end
                        len_cnt <= 5'b0;
                        result_reg <= 1'b0;
                        flag_ge2 <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule