module card_collection_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [7:0] M,
    input wire [7:0] targets [0:15],
    input wire [15:0] purchases [0:7],
    output reg out_valid,
    output reg [1:0] out_type,
    output reg [63:0] out_data,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS_INPUTS = 3'd1;
    localparam [2:0] FIX_DEFICITS = 3'd2;
    localparam [2:0] TRANSMIT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Current card counts for each child
    reg [7:0] current_counts [0:15];

    // Transaction buffer (up to 512 transactions, 24 bits each)
    reg [23:0] transaction_buffer [0:511];
    reg [8:0] transaction_count;
    reg [8:0] buffer_write_ptr;
    reg [8:0] buffer_read_ptr;

    // Processing variables
    reg [7:0] m_counter;
    reg [7:0] deficit_counter;
    reg [7:0] donor_child;
    reg [7:0] receiver_child;

    // Transmission variables
    reg [8:0] transmit_counter;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            out_valid <= 1'b0;
            out_type <= 2'd0;
            out_data <= 64'd0;
            done <= 1'b0;

            // Initialize current counts
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                current_counts[i] <= 8'd0;
            end

            // Initialize transaction buffer
            transaction_count <= 9'd0;
            buffer_write_ptr <= 9'd0;
            buffer_read_ptr <= 9'd0;

            // Initialize counters
            m_counter <= 8'd0;
            deficit_counter <= 8'd0;
            donor_child <= 8'd0;
            receiver_child <= 8'd0;
            transmit_counter <= 9'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                out_valid <= 1'b0;
                if (start) begin
                    next_state <= PROCESS_INPUTS;
                    m_counter <= 8'd0;
                    buffer_write_ptr <= 9'd0;
                    transaction_count <= 9'd0;
                end
            end

            PROCESS_INPUTS: begin
                if (m_counter < M) begin
                    // Process current purchase
                    reg [7:0] child_a = purchases[m_counter][7:0];
                    reg [7:0] child_b = purchases[m_counter][15:8];
                    reg [7:0] a_idx = child_a - 8'd1;
                    reg [7:0] b_idx = child_b - 8'd1;
                    reg [7:0] a_current = current_counts[a_idx];
                    reg [7:0] b_current = current_counts[b_idx];
                    reg [7:0] a_target = targets[a_idx];
                    reg [7:0] b_target = targets[b_idx];

                    reg [7:0] a_needs = (a_target > a_current) ? (a_target - a_current) : 8'd0;
                    reg [7:0] b_needs = (b_target > b_current) ? (b_target - b_current) : 8'd0;
                    reg [7:0] a_excess = (a_current > a_target) ? (a_current - a_target) : 8'd0;
                    reg [7:0] b_excess = (b_current > b_target) ? (b_current - b_target) : 8'd0;

                    reg [7:0] a_gets = 8'd0;
                    reg [7:0] b_gets = 8'd0;
                    reg [1:0] winner = 2'd0;

                    // Determine card distribution
                    if (a_needs > 8'd0 && b_excess >= 8'd2) begin
                        a_gets = 8'd2;
                        winner = 2'd1; // b gives to a
                    end else if (b_needs > 8'd0 && a_excess >= 8'd2) begin
                        b_gets = 8'd2;
                        winner = 2'd2; // a gives to b
                    end else if (a_needs > 8'd0 && b_needs > 8'd0) begin
                        a_gets = 8'd1;
                        b_gets = 8'd1;
                        winner = 2'd0; // both get 1
                    end else if (a_needs > 8'd0) begin
                        a_gets = 8'd2;
                        winner = 2'd1; // b gives to a
                    end else if (b_needs > 8'd0) begin
                        b_gets = 8'd2;
                        winner = 2'd2; // a gives to b
                    end else begin
                        a_gets = 8'd1;
                        winner = 2'd1; // arbitrary, b gives to a
                    end

                    // Update counts
                    current_counts[a_idx] <= a_current + a_gets;
                    current_counts[b_idx] <= b_current + b_gets;

                    // Store transaction
                    transaction_buffer[buffer_write_ptr] <= {child_a, child_b, winner};
                    buffer_write_ptr <= buffer_write_ptr + 9'd1;
                    transaction_count <= transaction_count + 9'd1;

                    m_counter <= m_counter + 8'd1;
                end else begin
                    next_state <= FIX_DEFICITS;
                    deficit_counter <= 8'd0;
                end
            end

            FIX_DEFICITS: begin
                reg [7:0] i;
                reg [7:0] j;
                reg [7:0] total_deficit = 8'd0;
                reg [7:0] total_excess = 8'd0;

                // Check if all targets are met
                reg all_met = 1'b1;
                for (i = 0; i < N; i = i + 1) begin
                    if (current_counts[i] != targets[i]) begin
                        all_met = 1'b0;
                    end
                end

                if (all_met) begin
                    next_state <= TRANSMIT;
                    transmit_counter <= 9'd0;
                    buffer_read_ptr <= 9'd0;
                end else begin
                    // Find a child with deficit
                    receiver_child = 8'd0;
                    for (i = 0; i < N; i = i + 1) begin
                        if (current_counts[i] < targets[i]) begin
                            receiver_child = i + 8'd1;
                            break;
                        end
                    end

                    // Find a child with excess (or use child 1 as donor)
                    donor_child = 8'd1;
                    for (j = 0; j < N; j = j + 1) begin
                        if (current_counts[j] > targets[j]) begin
                            donor_child = j + 8'd1;
                            break;
                        end
                    end

                    // Create transaction
                    reg [7:0] donor_idx = donor_child - 8'd1;
                    reg [7:0] receiver_idx = receiver_child - 8'd1;
                    reg [7:0] transfer_amount = (current_counts[donor_idx] > targets[donor_idx]) ? 8'd1 : 8'd0;

                    if (transfer_amount > 8'd0) begin
                        current_counts[donor_idx] <= current_counts[donor_idx] - transfer_amount;
                        current_counts[receiver_idx] <= current_counts[receiver_idx] + transfer_amount;

                        transaction_buffer[buffer_write_ptr] <= {donor_child, receiver_child, 2'd2};
                        buffer_write_ptr <= buffer_write_ptr + 9'd1;
                        transaction_count <= transaction_count + 9'd1;
                    end

                    deficit_counter <= deficit_counter + 8'd1;
                end
            end

            TRANSMIT: begin
                out_valid <= 1'b1;
                if (transmit_counter == 9'd0) begin
                    // Transmit total count
                    out_type <= 2'd0;
                    out_data <= {64'd0, transaction_count};
                    transmit_counter <= transmit_counter + 9'd1;
                end else if (transmit_counter <= transaction_count) begin
                    // Transmit transaction
                    out_type <= 2'd1;
                    out_data <= {64'd0, transaction_buffer[buffer_read_ptr]};
                    buffer_read_ptr <= buffer_read_ptr + 9'd1;
                    transmit_counter <= transmit_counter + 9'd1;
                end else begin
                    // Transmit end marker
                    out_type <= 2'd2;
                    out_data <= 64'd0;
                    next_state <= DONE_STATE;
                end
            end

            DONE_STATE: begin
                out_valid <= 1'b0;
                done <= 1'b1;
                next_state <= IDLE;
            end

            default: begin
                next_state <= IDLE;
                out_valid <= 1'b0;
            end
        endcase
    end

endmodule