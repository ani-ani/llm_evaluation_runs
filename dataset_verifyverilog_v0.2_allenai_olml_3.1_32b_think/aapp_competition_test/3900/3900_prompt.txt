module suspect_selection (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,           // Number of coders (max 8)
    input wire [2:0] p,           // Minimum agreement threshold
    input wire [7:0] x_arr,       // Packed array of x values (3 bits each, 8 coders max)
    input wire [7:0] y_arr,       // Packed array of y values (3 bits each, 8 coders max)
    output reg [5:0] result,      // Number of valid pairs
    output reg done               // High when computation is complete
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam ITERATE_PAIRS = 2'b01;
    localparam CALCULATE_AGREEMENT = 2'b10;
    localparam FINALIZE = 2'b11;

    reg [1:0] state, next_state;
    reg [2:0] u, v;               // Current pair of suspects
    reg [2:0] coder_idx;          // Current coder index
    reg [2:0] agreement_count;    // Agreement count for current pair
    reg [5:0] valid_pairs;        // Accumulated valid pairs

    // Helper signals to extract coder inputs
    wire [2:0] current_x, current_y;
    assign current_x = x_arr[coder_idx*3 +: 3];
    assign current_y = y_arr[coder_idx*3 +: 3];

    // Next state logic
    always @(state, u, v, n, coder_idx, agreement_count, p) begin
        case (state)
            IDLE: begin
                if (start) next_state = ITERATE_PAIRS;
                else next_state = IDLE;
            end
            ITERATE_PAIRS: begin
                if (u < n) next_state = CALCULATE_AGREEMENT;
                else next_state = FINALIZE;
            end
            CALCULATE_AGREEMENT: begin
                if (coder_idx < n) next_state = CALCULATE_AGREEMENT;
                else next_state = ITERATE_PAIRS;
            end
            FINALIZE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Output and state update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            u <= 0;
            v <= 0;
            coder_idx <= 0;
            agreement_count <= 0;
            valid_pairs <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        u <= 0;
                        v <= 1;
                        valid_pairs <= 0;
                    end
                end

                ITERATE_PAIRS: begin
                    if (u < n) begin
                        // Start processing this pair
                        coder_idx <= 0;
                        agreement_count <= 0;
                    end else begin
                        // All pairs processed
                        result <= valid_pairs;
                        done <= 1;
                    end
                end

                CALCULATE_AGREEMENT: begin
                    if (coder_idx < n) begin
                        // Check if this coder agrees with pair (u, v)
                        // Coder agrees if they named u OR v
                        if (current_x == u || current_y == u || current_x == v || current_y == v) begin
                            agreement_count <= agreement_count + 1;
                        end
                        coder_idx <= coder_idx + 1;
                    end else begin
                        // Finished counting for this pair
                        if (agreement_count >= p) begin
                            valid_pairs <= valid_pairs + 1;
                        end
                        // Increment pair
                        if (v < n - 1) begin
                            v <= v + 1;
                        end else begin
                            u <= u + 1;
                            v <= u + 2; // Start next row
                        end
                    end
                end

                FINALIZE: begin
                    done <= 1;
                end
            endcase
        end
    end
endmodule