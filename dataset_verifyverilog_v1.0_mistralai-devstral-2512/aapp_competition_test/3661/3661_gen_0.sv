module fair_lawsuit_ruling(
    input clk,
    input rst_n,
    input start,
    input lawyers_valid,
    input [2:0] ind_idx,
    input [2:0] corp_idx,
    input [3:0] lawsuit_idx,
    output reg ruling_valid,
    output reg ruling_party,
    output reg [3:0] ruling_id,
    output reg all_done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    reg [2:0] state, next_state;

    // Internal storage for lawsuits
    reg [2:0] ind_ram [0:15];
    reg [2:0] corp_ram [0:15];
    reg [3:0] lawsuit_count;
    reg [3:0] current_lawsuit;

    // Counters for wins
    reg [4:0] ind_wins [0:7];
    reg [4:0] corp_wins [0:7];

    // K value for binary search
    reg [4:0] K;
    reg [4:0] K_max;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            ruling_valid <= 1'b0;
            ruling_party <= 1'b0;
            ruling_id <= 4'd0;
            all_done <= 1'b0;
            lawsuit_count <= 4'd0;
            current_lawsuit <= 4'd0;
            cycle_count <= 8'd0;
            K <= 5'd0;
            K_max <= 5'd0;

            // Initialize win counters
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                ind_wins[i] <= 5'd0;
                corp_wins[i] <= 5'd0;
            end

            // Initialize lawsuit storage
            for (i = 0; i < 16; i = i + 1) begin
                ind_ram[i] <= 3'd0;
                corp_ram[i] <= 3'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    ruling_valid <= 1'b0;
                    all_done <= 1'b0;
                    if (start && lawyers_valid) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Store the lawsuit
                    ind_ram[lawsuit_idx] <= ind_idx;
                    corp_ram[lawsuit_idx] <= corp_idx;
                    lawsuit_count <= lawsuit_count + 4'd1;

                    // Move to next state if all lawsuits loaded or next lawsuit
                    if (lawsuit_count == 4'd15 || !lawyers_valid) begin
                        next_state <= CALCULATE;
                        current_lawsuit <= 4'd0;
                        K <= 5'd0;
                        K_max <= 5'd0;
                        cycle_count <= 8'd0;

                        // Reset win counters
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            ind_wins[i] <= 5'd0;
                            corp_wins[i] <= 5'd0;
                        end
                    end else begin
                        next_state <= LOAD;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Greedy assignment for current K
                    if (current_lawsuit < lawsuit_count) begin
                        reg [2:0] current_ind = ind_ram[current_lawsuit];
                        reg [2:0] current_corp = corp_ram[current_lawsuit];

                        // Assign based on win counts
                        if (ind_wins[current_ind] < K) begin
                            ruling_party <= 1'b0; // INDV wins
                            ind_wins[current_ind] <= ind_wins[current_ind] + 5'd1;
                        end else if (corp_wins[current_corp] < K) begin
                            ruling_party <= 1'b1; // CORP wins
                            corp_wins[current_corp] <= corp_wins[current_corp] + 5'd1;
                        end else begin
                            // Default to INDV if both at limit
                            ruling_party <= 1'b0;
                        end

                        current_lawsuit <= current_lawsuit + 4'd1;
                    end else begin
                        // Check if we need to increase K
                        reg feasible = 1'b1;
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (ind_wins[i] > K || corp_wins[i] > K) begin
                                feasible = 1'b0;
                            end
                        end

                        if (feasible || K == 5'd16 || cycle_count >= MAX_CYCLES) begin
                            next_state <= OUTPUT;
                            current_lawsuit <= 4'd0;
                        end else begin
                            // Reset and try next K
                            K <= K + 5'd1;
                            current_lawsuit <= 4'd0;

                            // Reset win counters
                            for (i = 0; i < 8; i = i + 1) begin
                                ind_wins[i] <= 5'd0;
                                corp_wins[i] <= 5'd0;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    ruling_valid <= 1'b1;
                    ruling_id <= current_lawsuit;

                    if (current_lawsuit == lawsuit_count - 4'd1) begin
                        all_done <= 1'b1;
                        next_state <= DONE;
                    end else begin
                        current_lawsuit <= current_lawsuit + 4'd1;
                        next_state <= OUTPUT;
                    end
                end

                DONE: begin
                    ruling_valid <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        all_done <= 1'b0;
                        lawsuit_count <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule