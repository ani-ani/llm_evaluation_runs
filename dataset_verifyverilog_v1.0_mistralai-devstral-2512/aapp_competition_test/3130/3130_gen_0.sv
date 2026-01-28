module EventCausalityEngine(
    input clk,
    input rst_n,
    input start,
    input [2:0] known_idx,
    input [3:0] known_val,
    input [3:0] implications_a,
    input [3:0] implications_b,
    input [3:0] impl_idx,
    input load_impl,
    input load_known,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOADING = 2'd1;
    localparam [1:0] CALCULATING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;

    // Implication table (16 entries x 8 bits: 4 bits for A, 4 bits for B)
    reg [7:0] implication_table [0:15];
    integer i;

    // Known events (8 entries x 4 bits)
    reg [3:0] known_events [0:7];

    // Certainty bitmask (8 bits for events 1-8)
    reg [7:0] certainty_mask;

    // Calculation control
    reg [7:0] pass_counter;
    reg [3:0] impl_counter;
    reg [3:0] current_a, current_b;
    reg all_effects_certain;
    reg [7:0] temp_mask;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize implication table and known events on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            certainty_mask <= 8'd0;
            pass_counter <= 8'd0;
            impl_counter <= 4'd0;
            cycle_count <= 8'd0;

            // Initialize implication table
            for (i = 0; i < 16; i = i + 1) begin
                implication_table[i] <= 8'd0;
            end

            // Initialize known events
            for (i = 0; i < 8; i = i + 1) begin
                known_events[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Load implications and known events
    always @(posedge clk) begin
        if (!rst_n) begin
            // Already handled in reset block
        end else begin
            if (load_impl && impl_idx < 16) begin
                implication_table[impl_idx] <= {implications_a, implications_b};
            end

            if (load_known && known_idx < 8) begin
                known_events[known_idx] <= known_val;
            end
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOADING;
                end
            end

            LOADING: begin
                next_state = CALCULATING;
            end

            CALCULATING: begin
                if (pass_counter >= 8'd15 || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
                done = 1'b1;
            end

            default: next_state = IDLE;
        endcase
    end

    // Calculation logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Already handled
        end else begin
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                end

                LOADING: begin
                    // Initialize certainty mask from known events
                    certainty_mask <= 8'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (known_events[i] > 0 && known_events[i] <= 8) begin
                            certainty_mask[known_events[i] - 1] <= 1'b1;
                        end
                    end
                    pass_counter <= 8'd0;
                    impl_counter <= 4'd0;
                    cycle_count <= 8'd0;
                end

                CALCULATING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Process one implication per cycle
                    if (impl_counter < 16) begin
                        current_a <= implication_table[impl_counter][7:4];
                        current_b <= implication_table[impl_counter][3:0];

                        // Check if current_b is certain and current_a is not
                        if (current_b > 0 && current_b <= 8 && 
                            current_a > 0 && current_a <= 8 &&
                            certainty_mask[current_b - 1] && 
                            !certainty_mask[current_a - 1]) begin

                            // Check if all effects of current_a are certain
                            all_effects_certain = 1'b1;
                            temp_mask <= certainty_mask;

                            for (i = 0; i < 16; i = i + 1) begin
                                if (implication_table[i][7:4] == current_a) begin
                                    reg [3:0] effect_event;
                                    effect_event <= implication_table[i][3:0];
                                    if (effect_event > 0 && effect_event <= 8 && 
                                        !temp_mask[effect_event - 1]) begin
                                        all_effects_certain = 1'b0;
                                    end
                                end
                            end

                            if (all_effects_certain) begin
                                certainty_mask[current_a - 1] <= 1'b1;
                            end
                        end

                        impl_counter <= impl_counter + 4'd1;
                    end else begin
                        impl_counter <= 4'd0;
                        pass_counter <= pass_counter + 8'd1;
                    end
                end

                DONE_STATE: begin
                    result <= certainty_mask;
                end

                default: ;
            endcase
        end
    end

endmodule