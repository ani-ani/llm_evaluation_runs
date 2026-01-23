module treasure_map_solver(
    input clk,
    input rst_n,
    input start,
    input [5:0] str_len,
    input [255:0] str_data,
    output reg [4:0] sharp_count,
    output reg [31:0] result_packed,
    output reg valid,
    output reg error
);

    // FSM States
    localparam IDLE = 2'b00;
    localparam COUNT = 2'b01;
    localparam VALIDATE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [5:0] idx;
    reg [5:0] current_sharp_idx; // Index of the current sharp being processed (0-based)
    reg [5:0] total_opens;
    reg [5:0] total_closes;
    reg [5:0] balance;
    reg [5:0] diff;
    reg [5:0] temp_result [0:4]; // Temporary storage for up to 5 results
    
    // Helper logic to extract current character
    wire [7:0] current_char;
    assign current_char = str_data[(idx << 3) +: 8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sharp_count <= 0;
            result_packed <= 0;
            valid <= 0;
            error <= 0;
            idx <= 0;
            total_opens <= 0;
            total_closes <= 0;
            balance <= 0;
            current_sharp_idx <= 0;
            diff <= 0;
            // temp_result initialization not strictly necessary but good practice
        end else begin
            case (state)
                IDLE: begin
                    valid <= 0;
                    error <= 0;
                    idx <= 0;
                    sharp_count <= 0;
                    total_opens <= 0;
                    total_closes <= 0;
                    balance <= 0;
                    current_sharp_idx <= 0;
                    if (start) begin
                        state <= COUNT;
                    end else begin
                        state <= IDLE;
                    end
                end

                COUNT: begin
                    if (idx < str_len) begin
                        // Process character
                        if (current_char == 8'h28) begin // '(' = 0x28
                            total_opens <= total_opens + 1;
                            balance <= balance + 1;
                        end else if (current_char == 8'h29) begin // ')' = 0x29
                            total_closes <= total_closes + 1;
                            if (balance > 0) begin
                                balance <= balance - 1;
                            end else begin
                                // Error: balance drops below 0
                                state <= DONE;
                                error <= 1;
                                valid <= 1;
                            end
                        end else if (current_char == 8'h23) begin // '#' = 0x23
                            sharp_count <= sharp_count + 1;
                        end
                        idx <= idx + 1;
                    end else begin
                        // End of string in Count phase
                        if (error) begin
                            // Handled in done state
                        end else begin
                            // Check Feasibility
                            // diff = total_opens - total_closes - sharp_count
                            // Note: balance currently holds (total_opens - total_closes) for valid prefixes
                            diff <= balance - sharp_count;
                            
                            if (balance < sharp_count) begin
                                // Equivalent to diff < 0
                                state <= DONE;
                                error <= 1;
                                valid <= 1;
                            end else begin
                                state <= VALIDATE;
                                idx <= 0;
                                current_sharp_idx <= 0;
                                balance <= 0; // Reset balance for validation pass
                                result_packed <= 0;
                            end
                        end
                    end
                end

                VALIDATE: begin
                    if (idx < str_len) begin
                        // Process character
                        if (current_char == 8'h28) begin // '('
                            balance <= balance + 1;
                        end else if (current_char == 8'h29) begin // ')'
                            if (balance > 0) balance <= balance - 1;
                            else begin
                                state <= DONE;
                                error <= 1;
                                valid <= 1;
                            end
                        end else if (current_char == 8'h23) begin // '#'
                            if (current_sharp_idx < sharp_count) begin
                                // Determine deduction amount
                                // Last sharp: diff + 1
                                // Others: 1
                                // Since diff >= 0 in this state, diff+1 >= 1
                                reg [5:0] deduction;
                                if (current_sharp_idx == sharp_count - 1) deduction = diff + 1;
                                else deduction = 1;

                                // Pack result
                                // result_packed is 32 bits, 5 results * 6 bits
                                // idx 0 -> [5:0], idx 1 -> [11:6], ...
                                case (current_sharp_idx)
                                    0: result_packed[5:0] <= deduction;
                                    1: result_packed[11:6] <= deduction;
                                    2: result_packed[17:12] <= deduction;
                                    3: result_packed[23:18] <= deduction;
                                    4: result_packed[29:24] <= deduction;
                                    default: ; // Should not happen with max 5 sharps
                                endcase

                                // Check balance
                                // In problem statement: "If balance < 0 at any point"
                                // Since we subtract 'deduction', we need to ensure balance >= deduction
                                if (balance < deduction) begin
                                    state <= DONE;
                                    error <= 1;
                                    valid <= 1;
                                end else begin
                                    balance <= balance - deduction;
                                    current_sharp_idx <= current_sharp_idx + 1;
                                end
                            end else begin
                                // More sharps than counted? Should not happen if logic is correct
                                state <= DONE;
                                error <= 1;
                                valid <= 1;
                            end
                        end
                        idx <= idx + 1;
                    end else begin
                        // End of string in Validation phase
                        // If we reached here without error, it's a success
                        state <= DONE;
                        error <= 0;
                        valid <= 1;
                    end
                end

                DONE: begin
                    // Stay in DONE until reset or start goes low (assumption: start is pulsed)
                    // If start is held high, we might restart immediately depending on requirements.
                    // Typically FSMs wait for start to go low.
                    // We will reset valid/error when start goes high in IDLE.
                    if (!start) begin
                        state <= IDLE;
                        valid <= 0;
                        error <= 0;
                    end else begin
                        state <= DONE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
