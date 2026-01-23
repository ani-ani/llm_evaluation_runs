module hanabi_solver (
    input clk,
    input rst_n,
    input start,
    input [4:0] unique_cards_count,
    input [15:0] card_attributes [0:15],
    output reg [3:0] min_hints,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Processing variables
    reg [9:0] mask;
    reg [3:0] current_hint_count;
    reg [3:0] min_hints_reg;
    reg [3:0] i, j;
    reg valid_mask;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            mask <= 0;
            min_hints_reg <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PROCESSING;
            end
            PROCESSING: begin
                if (mask == 1023) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= 0;
            min_hints_reg <= 0;
            i <= 0;
            j <= 0;
            valid_mask <= 0;
        end else if (current_state == PROCESSING) begin
            // Check all card pairs for current mask
            if (i < unique_cards_count && j < unique_cards_count) begin
                if (i != j) begin
                    // Check if cards differ in at least one hinted attribute
                    reg [15:0] card1 = card_attributes[i];
                    reg [15:0] card2 = card_attributes[j];
                    reg [15:0] masked1 = card1 & {10{mask}};
                    reg [15:0] masked2 = card2 & {10{mask}};
                    
                    if (masked1 == masked2) begin
                        valid_mask = 0;
                    end
                    j <= j + 1;
                end else begin
                    j <= j + 1;
                end
            end else begin
                // All pairs checked for this mask
                if (valid_mask) begin
                    current_hint_count = $countones(mask);
                    if (min_hints_reg == 0 || current_hint_count < min_hints_reg) begin
                        min_hints_reg = current_hint_count;
                    end
                end
                
                // Move to next mask
                mask <= mask + 1;
                i <= 0;
                j <= 0;
                valid_mask <= 1;
            end
        end
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_hints <= 0;
            done <= 0;
        end else begin
            min_hints <= min_hints_reg;
            done <= (current_state == DONE);
        end
    end

endmodule