module multi_knapsack_dp (
    input clk,
    input rst_n,
    input start,
    input [7:0] jewel_size,
    input [7:0] jewel_value,
    input valid_in,
    output reg [7:0] current_max_value,
    output reg [3:0] current_size,
    output reg done,
    output reg result_valid
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam READ_JEWELS = 3'b001;
    localparam UPDATE = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam DONE = 3'b100;

    // DP table for knapsack sizes 1 to 16 (k=16)
    reg [7:0] dp [0:15]; // dp[0] unused, dp[1] to dp[15] used

    // State machine
    reg [2:0] state = IDLE;
    reg [2:0] next_state = IDLE;

    // Counters
    reg [3:0] jewel_count = 0; // Max 8 jewels
    reg [3:0] size_counter = 0; // For UPDATE and OUTPUT states
    reg [3:0] output_counter = 0; // For OUTPUT state

    // Control signals
    reg jewel_processed = 0;
    reg output_started = 0;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            jewel_count <= 0;
            size_counter <= 0;
            output_counter <= 0;
            jewel_processed <= 0;
            output_started <= 0;
            done <= 0;
            result_valid <= 0;
            current_max_value <= 0;
            current_size <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_JEWELS;
                end
            end
            READ_JEWELS: begin
                if (valid_in) begin
                    next_state = UPDATE;
                end
            end
            UPDATE: begin
                if (size_counter == 15) begin
                    if (jewel_count == 7) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = READ_JEWELS;
                    end
                end
            end
            OUTPUT: begin
                if (output_counter == 15) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize DP table
            for (int i = 0; i < 16; i = i + 1) begin
                dp[i] <= 0;
            end
            jewel_count <= 0;
            size_counter <= 0;
            output_counter <= 0;
            jewel_processed <= 0;
            output_started <= 0;
            done <= 0;
            result_valid <= 0;
            current_max_value <= 0;
            current_size <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Initialize DP table on start
                    if (start) begin
                        for (int i = 0; i < 16; i = i + 1) begin
                            dp[i] <= 0;
                        end
                        jewel_count <= 0;
                        size_counter <= 0;
                        output_counter <= 0;
                        jewel_processed <= 0;
                        output_started <= 0;
                        done <= 0;
                        result_valid <= 0;
                        current_max_value <= 0;
                        current_size <= 0;
                    end
                end
                READ_JEWELS: begin
                    if (valid_in) begin
                        jewel_processed <= 1;
                    end
                end
                UPDATE: begin
                    if (jewel_processed) begin
                        if (size_counter == 0) begin
                            size_counter <= 15;
                        end else begin
                            size_counter <= size_counter - 1;
                        end
                        if (size_counter >= jewel_size) begin
                            // Update DP table
                            if (dp[size_counter] < (dp[size_counter - jewel_size] + jewel_value)) begin
                                dp[size_counter] <= dp[size_counter - jewel_size] + jewel_value;
                            end
                        end
                        if (size_counter == 0) begin
                            jewel_processed <= 0;
                            if (jewel_count == 7) begin
                                jewel_count <= 0;
                            end else begin
                                jewel_count <= jewel_count + 1;
                            end
                        end
                    end
                end
                OUTPUT: begin
                    if (!output_started) begin
                        output_started <= 1;
                        output_counter <= 0;
                    end else begin
                        if (output_counter == 0) begin
                            output_counter <= 15;
                        end else begin
                            output_counter <= output_counter - 1;
                        end
                        current_size <= output_counter + 1;
                        current_max_value <= dp[output_counter];
                        result_valid <= 1;
                        if (output_counter == 0) begin
                            output_started <= 0;
                            result_valid <= 0;
                        end
                    end
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule