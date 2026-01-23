module magic_boxes (
    input clk,
    input rst_n,
    input start,
    input [4:0] k_in,
    input [19:0] a_in,
    input [1:0] type_index,
    input valid_in,
    output reg [5:0] result,
    output reg done
);

    // Internal storage for 4 box types
    reg [4:0] k_reg [0:3];
    reg [19:0] a_reg [0:3];
    reg [3:0] input_stored;

    // Computation registers
    reg [5:0] current_max;
    reg [5:0] calc_k;
    reg [19:0] calc_a;
    reg [3:0] calc_idx;
    
    // Log4 computation signals
    wire [3:0] log4_val;
    wire [5:0] p_k_candidate;
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam CAPTURE = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam DONE_STATE = 2'b11;
    
    reg [1:0] state, next_state;
    
    // Log4 Lookup Logic: ceil(log4(a))
    // 0 if a <= 1
    // 1 if 2 <= a <= 4 (2,3,4)
    // 2 if 5 <= a <= 16 (5..16)
    // 3 if 17 <= a <= 64
    // 4 if 65 <= a <= 256
    // 5 if 257 <= a <= 1024
    // 6 if 1025 <= a <= 4096
    // 7 if 4097 <= a <= 16384
    // 8 if 16385 <= a <= 65536
    // 9 if 65537 <= a <= 262144
    // 10 if 262145 <= a <= 1048576 (max a_in is 2^20-1)
    
    always @(*) begin
        if (calc_a <= 1) log4_val = 0;
        else if (calc_a <= 4) log4_val = 1;
        else if (calc_a <= 16) log4_val = 2;
        else if (calc_a <= 64) log4_val = 3;
        else if (calc_a <= 256) log4_val = 4;
        else if (calc_a <= 1024) log4_val = 5;
        else if (calc_a <= 4096) log4_val = 6;
        else if (calc_a <= 16384) log4_val = 7;
        else if (calc_a <= 65536) log4_val = 8;
        else if (calc_a <= 262144) log4_val = 9;
        else log4_val = 10;
    end

    // Calculate candidate p_k (k + log4)
    assign p_k_candidate = calc_k + log4_val;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CAPTURE;
                else next_state = IDLE;
            end
            CAPTURE: begin
                // Wait until all 4 types are captured
                if (&input_stored) next_state = COMPUTE;
                else next_state = CAPTURE;
            end
            COMPUTE: begin
                // Iterate through indices 0 to 3, then go to DONE
                if (calc_idx == 4) next_state = DONE_STATE;
                else next_state = COMPUTE;
            end
            DONE_STATE: begin
                // Stay in DONE until reset or new start
                if (start) next_state = CAPTURE;
                else next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_stored <= 4'b0;
            current_max <= 6'b0;
            calc_idx <= 4'd0;
            calc_k <= 5'b0;
            calc_a <= 20'b0;
            result <= 6'b0;
            done <= 1'b0;
            // Reset storage
            k_reg[0] <= 5'b0; k_reg[1] <= 5'b0; k_reg[2] <= 5'b0; k_reg[3] <= 5'b0;
            a_reg[0] <= 20'b0; a_reg[1] <= 20'b0; a_reg[2] <= 20'b0; a_reg[3] <= 20'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        input_stored <= 4'b0;
                        current_max <= 6'b0;
                        calc_idx <= 4'd0;
                        result <= 6'b0;
                    end
                end

                CAPTURE: begin
                    // Capture inputs when valid_in is high
                    if (valid_in) begin
                        k_reg[type_index] <= k_in;
                        a_reg[type_index] <= a_in;
                        input_stored[type_index] <= 1'b1;
                    end
                end

                COMPUTE: begin
                    if (calc_idx < 4) begin
                        // Load data for current index
                        calc_k <= k_reg[calc_idx];
                        calc_a <= a_reg[calc_idx];
                        
                        // Update max if this type was stored
                        if (input_stored[calc_idx]) begin
                            if (p_k_candidate > current_max)
                                current_max <= p_k_candidate;
                        end
                        
                        calc_idx <= calc_idx + 1;
                    end else begin
                        // Computation cycle complete, latch result
                        result <= current_max;
                        done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    // Result is already latched and done is high
                    // Wait for reset or start
                    if (start) begin
                        // Preparing for new transaction (handled in next state transition)
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
