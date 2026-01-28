module DogFoodBowlEater(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    input wire [15:0] T_limit,
    input wire [15:0] t_arr [0:63],
    output reg [6:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Registers for state and iteration
    reg [1:0] state;
    reg [5:0] i;               // Iteration counter (0 to 63)
    reg [6:0] count;           // Accumulated bowl count

    // Internal signals for combinational logic
    reg [15:0] pos;            // Bowl position (1-based)
    reg [15:0] wait_time;
    reg [15:0] finish_time;
    reg valid;
    
    // Latched inputs
    reg [5:0] n_reg;
    reg [15:0] T_limit_reg;
    reg [15:0] t_arr_reg [0:63];

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 7'd0;
            done <= 1'b0;
            i <= 6'd0;
            count <= 7'd0;
            n_reg <= 6'd0;
            T_limit_reg <= 16'd0;
            // Reset latched array
            for (k = 0; k < 64; k = k + 1) begin
                t_arr_reg[k] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 6'd0;
                    count <= 7'd0;
                    if (start) begin
                        // Latch inputs
                        n_reg <= n;
                        T_limit_reg <= T_limit;
                        for (k = 0; k < 64; k = k + 1) begin
                            t_arr_reg[k] <= t_arr[k];
                        end
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    // Pre-calculate logic for current iteration i
                    pos = i + 16'd1; // Bowl position is 1-based
                    
                    // Wait time logic: if t_arr[i] > pos, wait = t_arr[i] - pos
                    if (t_arr_reg[i] > pos) begin
                        wait_time = t_arr_reg[i] - pos;
                    end else begin
                        wait_time = 16'd0;
                    end
                    
                    finish_time = pos + wait_time;
                    
                    // Valid if finish_time < T_limit AND i < n_reg
                    valid = (finish_time < T_limit_reg) && (i < n_reg);
                    
                    // Update count
                    if (valid) begin
                        count <= count + 7'd1;
                    end
                    
                    // Increment iteration counter
                    i <= i + 6'd1;
                    
                    // Check for completion
                    if (i >= 63) begin // Max index is 63 for 64 bowls
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule