module NewmanConwaySequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_INIT  = 2'd1;
    localparam [1:0] S_COMP  = 2'd2;
    localparam [1:0] S_DONE  = 2'd3;

    // Internal signals
    reg [1:0] state, next_state;
    reg [3:0] n_reg;
    reg [3:0] i;
    reg [15:0] sequence [0:15];
    reg [15:0] s_prev, s_sub;
    reg [15:0] temp_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            i <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = S_IDLE;
        case (state)
            S_IDLE: begin
                if (start && n_in >= 4'd1 && n_in <= 4'd15) begin
                    next_state = S_INIT;
                end
            end

            S_INIT: begin
                next_state = S_COMP;
            end

            S_COMP: begin
                if (i == n_reg) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_COMP;
                end
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialization in reset handled above
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    // Handle n=1 and n=2 cases immediately
                    if (start && n_in == 4'd1) begin
                        result <= 16'd1;
                        done <= 1'b1;
                    end else if (start && n_in == 4'd2) begin
                        result <= 16'd1;
                        done <= 1'b1;
                    end else if (start && n_in >= 4'd3 && n_in <= 4'd15) begin
                        n_reg <= n_in;
                        i <= 4'd3;
                    end
                end

                S_INIT: begin
                    // Initialize sequence[1] and sequence[2]
                    sequence[1] <= 16'd1;
                    sequence[2] <= 16'd1;
                    i <= 4'd3;
                    cycle_count <= cycle_count + 8'd1;
                end

                S_COMP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Read S(i-1)
                    s_prev <= sequence[i - 4'd1];
                    
                    // Compute index: i - S(i-1)
                    temp_idx <= i - s_prev;
                    
                    // Read S(i - S(i-1))
                    s_sub <= sequence[temp_idx];
                    
                    // Store result: S(i) = S(S(i-1)) + S(i - S(i-1))
                    sequence[i] <= sequence[s_prev] + s_sub;
                    
                    // Increment counter
                    if (i < n_reg) begin
                        i <= i + 4'd1;
                    end
                end

                S_DONE: begin
                    result <= sequence[n_reg];
                    done <= 1'b1;
                    // Clear done after one cycle
                    if (cycle_count < MAX_CYCLES) begin
                        done <= 1'b0;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule