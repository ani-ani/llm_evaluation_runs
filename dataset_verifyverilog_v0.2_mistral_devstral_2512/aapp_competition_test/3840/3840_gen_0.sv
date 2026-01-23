module pirate_chest_solver (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [15:0] coins [0:14],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        VALIDATE,
        PROCESS_LOOP,
        CALCULATE_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] moves;
    reg [4:0] current_chest;
    reg [15:0] temp_coins [0:14];
    reg [4:0] i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            moves <= 0;
            current_chest <= 0;
            for (int j = 0; j < 15; j = j + 1) begin
                temp_coins[j] <= 0;
            end
            i <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = VALIDATE;
            end
            VALIDATE: begin
                if (n == 1 || n[0] == 0) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESS_LOOP;
                end
            end
            PROCESS_LOOP: begin
                if (i == n) begin
                    next_state = CALCULATE_RESULT;
                end
            end
            CALCULATE_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                end
                VALIDATE: begin
                    if (n == 1 || n[0] == 0) begin
                        result <= -1;
                        done <= 1;
                    end else begin
                        // Initialize temp_coins
                        for (int j = 0; j < 15; j = j + 1) begin
                            temp_coins[j] <= coins[j];
                        end
                        i <= n;
                        moves <= 0;
                    end
                end
                PROCESS_LOOP: begin
                    if (i > 0) begin
                        current_chest <= i - 1; // Convert to 0-based index
                        if (temp_coins[current_chest] > 0) begin
                            // Calculate parent index (integer division by 2)
                            reg [4:0] parent = (current_chest + 1) / 2 - 1;
                            
                            // Add coins to moves
                            moves <= moves + temp_coins[current_chest];
                            
                            // Subtract from parent
                            if (parent >= 0) begin
                                if (temp_coins[parent] >= temp_coins[current_chest]) begin
                                    temp_coins[parent] <= temp_coins[parent] - temp_coins[current_chest];
                                end else begin
                                    temp_coins[parent] <= 0;
                                end
                            end
                            
                            // Subtract from sibling if odd
                            if ((current_chest + 1) % 2 == 1 && current_chest > 0) begin
                                reg [4:0] sibling = current_chest - 1;
                                if (temp_coins[sibling] >= temp_coins[current_chest]) begin
                                    temp_coins[sibling] <= temp_coins[sibling] - temp_coins[current_chest];
                                end else begin
                                    temp_coins[sibling] <= 0;
                                end
                            end
                            
                            // Clear current chest
                            temp_coins[current_chest] <= 0;
                        end
                        i <= i - 1;
                    end
                end
                CALCULATE_RESULT: begin
                    result <= moves;
                    done <= 1;
                end
                DONE: begin
                    // Stay in DONE until reset
                end
            endcase
        end
    end

endmodule