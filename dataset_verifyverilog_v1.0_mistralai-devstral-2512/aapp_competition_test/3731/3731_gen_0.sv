module distinct_letters_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] a_in,
    input wire [3:0] b_in,
    input wire [31:0] l_in,
    input wire [31:0] r_in,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] GENERATE_SEQ = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Sequence storage
    reg [3:0] seq_storage [0:47];
    reg [5:0] period;

    // Calculation variables
    reg [31:0] l_norm, r_norm;
    reg [31:0] current_index;
    reg [12:0] seen_mask;
    reg [3:0] current_letter;
    reg [7:0] distinct_count;
    reg full_period_coverage;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            period <= 6'd0;
            l_norm <= 32'd0;
            r_norm <= 32'd0;
            current_index <= 32'd0;
            seen_mask <= 13'd0;
            distinct_count <= 8'd0;
            full_period_coverage <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = GENERATE_SEQ;
                end else begin
                    next_state = IDLE;
                end
            end

            GENERATE_SEQ: begin
                next_state = CALCULATE;
            end

            CALCULATE: begin
                if (full_period_coverage || (current_index >= r_norm)) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CALCULATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequence generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize sequence storage
            integer i;
            for (i = 0; i < 48; i = i + 1) begin
                seq_storage[i] <= 4'd0;
            end
        end else if (state == GENERATE_SEQ) begin
            // Compute period
            period = 2 * (a_in + b_in);

            // Generate sequence
            integer i;
            for (i = 0; i < period; i = i + 1) begin
                if (i < a_in) begin
                    seq_storage[i] = i;
                end else if (i < a_in + b_in) begin
                    seq_storage[i] = a_in;
                end else if (i < 2 * a_in + b_in) begin
                    seq_storage[i] = i - b_in;
                end else begin
                    seq_storage[i] = a_in;
                end
            end
        end
    end

    // Calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset calculation variables
            l_norm <= 32'd0;
            r_norm <= 32'd0;
            current_index <= 32'd0;
            seen_mask <= 13'd0;
            distinct_count <= 8'd0;
            full_period_coverage <= 1'b0;
        end else if (state == CALCULATE) begin
            if (cycle_count == 8'd0) begin
                // Normalize l and r
                l_norm = ((l_in - 1) % period) + 1;
                r_norm = ((r_in - 1) % period) + 1;

                // Check if range spans full period
                if ((r_in - l_in) >= period) begin
                    full_period_coverage = 1'b1;
                    distinct_count = a_in + 1;
                end else if (l_norm <= r_norm) begin
                    // Single segment
                    current_index = l_norm;
                    seen_mask = 13'd0;
                    distinct_count = 8'd0;
                end else begin
                    // Wrap-around case
                    current_index = l_norm;
                    seen_mask = 13'd0;
                    distinct_count = 8'd0;
                end
            end else begin
                if (!full_period_coverage) begin
                    // Process current index
                    current_letter = seq_storage[current_index - 1];
                    if (!seen_mask[current_letter]) begin
                        seen_mask[current_letter] = 1'b1;
                        distinct_count = distinct_count + 8'd1;
                    end

                    // Move to next index
                    if (current_index == period) begin
                        current_index = 1'b1;
                    end else begin
                        current_index = current_index + 32'd1;
                    end
                end
            end

            cycle_count = cycle_count + 8'd1;
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                GENERATE_SEQ: begin
                    done <= 1'b0;
                end

                CALCULATE: begin
                    done <= 1'b0;
                end

                DONE_STATE: begin
                    result <= distinct_count;
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule