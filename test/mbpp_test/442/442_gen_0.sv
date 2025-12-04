module positive_ratio (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [3:0]  array_size,
    input  logic signed [15:0] nums [0:15],
    output logic [15:0] ratio,
    output logic        done
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        COUNT = 2'b01,
        WAIT  = 2'b10
    } state_t;

    state_t        state, next_state;
    logic [4:0]    idx;            // up to 16
    logic [4:0]    pos_count;      // positive count up to 16
    logic [4:0]    cycle_cnt;      // to enforce 20-cycle latency
    logic [15:0]   ratio_reg;
    logic          done_reg;

    // Output assignments
    assign ratio = ratio_reg;
    assign done  = done_reg;

    // Next-state and control logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COUNT;
            end
            COUNT: begin
                // After processing all elements, move to WAIT
                if (idx == array_size)
                    next_state = WAIT;
            end
            WAIT: begin
                // After 20 cycles total since start, go back to IDLE
                if (cycle_cnt == 5'd19)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            idx        <= 5'd0;
            pos_count  <= 5'd0;
            cycle_cnt  <= 5'd0;
            ratio_reg  <= 16'd0;
            done_reg   <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done_reg  <= 1'b0;
                    ratio_reg <= 16'd0;
                    cycle_cnt <= 5'd0;
                    idx       <= 5'd0;
                    pos_count <= 5'd0;
                    if (start) begin
                        // Start counting next cycle in COUNT state
                        cycle_cnt <= 5'd0; // will increment below
                    end
                end

                COUNT: begin
                    // Global cycle counter for 20-cycle latency
                    cycle_cnt <= cycle_cnt + 5'd1;

                    if (idx < array_size) begin
                        if (nums[idx] > 16'sd0)
                            pos_count <= pos_count + 5'd1;
                        idx <= idx + 5'd1;
                    end

                    // When finished counting (idx == array_size), compute ratio once
                    if ((idx == array_size) && (next_state == WAIT)) begin
                        if (array_size != 4'd0) begin
                            // ratio = round((pos_count * 256) / array_size)
                            // rounding: add array_size/2 before division
                            logic [15:0] scaled;
                            logic [8:0]  half_div;
                            scaled   = {pos_count, 8'd0};
                            half_div = {5'd0, array_size} >> 1; // array_size/2
                            ratio_reg <= (scaled + half_div) / array_size;
                        end else begin
                            ratio_reg <= 16'd0;
                        end
                    end
                end

                WAIT: begin
                    // Continue counting cycles to reach 20 total
                    cycle_cnt <= cycle_cnt + 5'd1;

                    // Assert done at the end of 20th cycle (cycle_cnt == 19)
                    if (cycle_cnt == 5'd19) begin
                        done_reg <= 1'b1;
                    end else begin
                        done_reg <= 1'b0;
                    end
                end

                default: begin
                    state      <= IDLE;
                    idx        <= 5'd0;
                    pos_count  <= 5'd0;
                    cycle_cnt  <= 5'd0;
                    ratio_reg  <= 16'd0;
                    done_reg   <= 1'b0;
                end
            endcase
        end
    end

endmodule