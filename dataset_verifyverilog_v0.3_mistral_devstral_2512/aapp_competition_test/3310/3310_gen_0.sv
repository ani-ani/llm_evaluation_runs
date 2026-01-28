module restaurant_expected(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] g,
    input [7:0] t,
    input [7:0] c0,
    input [7:0] c1,
    input [7:0] c2,
    input [7:0] c3,
    output reg [15:0] sum_occupancy,
    output reg [15:0] count_sequences,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] NEXT_SEQ = 3'd2;
    localparam [2:0] SIM_HOUR = 3'd3;
    localparam [2:0] UPDATE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] current_seq;
    reg [15:0] total_sequences;
    reg [15:0] current_occupancy;
    reg [15:0] total_occupancy;
    reg [7:0] current_hour;
    reg [7:0] current_group;
    reg [7:0] sorted_c [0:3];
    reg [7:0] table_occupancy [0:3];
    reg [7:0] group_sizes [0:3];
    reg [7:0] i, j, k;
    reg found_table;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_seq <= 16'd0;
            total_sequences <= 16'd0;
            current_occupancy <= 16'd0;
            total_occupancy <= 16'd0;
            current_hour <= 8'd0;
            current_group <= 8'd0;
            sorted_c[0] <= 8'd0;
            sorted_c[1] <= 8'd0;
            sorted_c[2] <= 8'd0;
            sorted_c[3] <= 8'd0;
            for (i = 0; i < 4; i = i + 1) begin
                table_occupancy[i] <= 8'd0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                group_sizes[i] <= 8'd0;
            end
            sum_occupancy <= 16'd0;
            count_sequences <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            INIT: begin
                next_state = NEXT_SEQ;
            end

            NEXT_SEQ: begin
                if (current_seq < total_sequences) begin
                    next_state = SIM_HOUR;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            SIM_HOUR: begin
                if (current_hour < t) begin
                    next_state = UPDATE;
                end else begin
                    next_state = NEXT_SEQ;
                end
            end

            UPDATE: begin
                next_state = SIM_HOUR;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                INIT: begin
                    // Sort capacities
                    sorted_c[0] = c0;
                    sorted_c[1] = c1;
                    sorted_c[2] = c2;
                    sorted_c[3] = c3;

                    // Bubble sort
                    for (i = 0; i < 3; i = i + 1) begin
                        for (j = 0; j < 3 - i; j = j + 1) begin
                            if (sorted_c[j] > sorted_c[j + 1]) begin
                                k = sorted_c[j];
                                sorted_c[j] = sorted_c[j + 1];
                                sorted_c[j + 1] = k;
                            end
                        end
                    end

                    // Calculate total sequences
                    total_sequences = 16'd1;
                    for (i = 0; i < t; i = i + 1) begin
                        total_sequences = total_sequences * g;
                    end

                    count_sequences = total_sequences;
                    current_seq = 16'd0;
                    current_occupancy = 16'd0;
                    total_occupancy = 16'd0;
                end

                NEXT_SEQ: begin
                    // Reset for new sequence
                    current_hour = 8'd0;
                    current_occupancy = 16'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        table_occupancy[i] = 8'd0;
                    end

                    // Convert sequence number to group sizes
                    k = current_seq;
                    for (i = 0; i < t; i = i + 1) begin
                        group_sizes[i] = k % g + 1'b1;
                        k = k / g;
                    end

                    current_seq = current_seq + 16'd1;
                end

                SIM_HOUR: begin
                    // Get current group size
                    current_group = group_sizes[current_hour];

                    // Find smallest table that can accommodate
                    found_table = 1'b0;
                    for (i = 0; i < n; i = i + 1) begin
                        if (!found_table && table_occupancy[i] == 8'd0 && sorted_c[i] >= current_group) begin
                            table_occupancy[i] = current_group;
                            found_table = 1'b1;
                        end
                    end

                    // Update occupancy
                    for (i = 0; i < n; i = i + 1) begin
                        current_occupancy = current_occupancy + table_occupancy[i];
                    end

                    current_hour = current_hour + 8'd1;
                end

                UPDATE: begin
                    // Clear tables for next hour
                    for (i = 0; i < n; i = i + 1) begin
                        table_occupancy[i] = 8'd0;
                    end

                    // Accumulate total occupancy
                    total_occupancy = total_occupancy + current_occupancy;
                end

                DONE_STATE: begin
                    sum_occupancy = total_occupancy;
                    done = 1'b1;
                end

                default: begin
                    done = 1'b0;
                end
            endcase
        end
    end

endmodule