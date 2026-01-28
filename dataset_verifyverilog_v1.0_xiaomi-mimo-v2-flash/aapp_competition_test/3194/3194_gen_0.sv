module PhotoScheduling (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [5:0] t,
    input wire [15:0] a [0:7],
    input wire [15:0] b [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] SORT  = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] DONE  = 2'd3;

    reg [1:0] state, next_state;
    
    // Internal registers
    reg [15:0] a_sorted [0:7];
    reg [15:0] b_sorted [0:7];
    reg [15:0] current_time;
    reg [3:0] counter;
    reg valid;
    reg [5:0] t_reg;
    reg [3:0] n_reg;
    reg [3:0] sort_counter;
    reg [3:0] i, j;
    
    // Temporary registers for swap
    reg [15:0] temp_a;
    reg [15:0] temp_b;
    
    // Computation registers
    reg [15:0] start_time;
    reg [15:0] end_time;
    reg possible;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            current_time <= 16'd0;
            counter <= 4'd0;
            sort_counter <= 4'd0;
            valid <= 1'b1;
            i <= 4'd0;
            j <= 4'd0;
            temp_a <= 16'd0;
            temp_b <= 16'd0;
            start_time <= 16'd0;
            end_time <= 16'd0;
            possible <= 1'b0;
            // Initialize sorted arrays
            for (int k = 0; k < 8; k = k + 1) begin
                a_sorted[k] <= 16'd0;
                b_sorted[k] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    sort_counter <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    current_time <= 16'd0;
                    valid <= 1'b1;
                    t_reg <= t;
                    n_reg <= n;
                    // Copy input to sorted arrays
                    if (start) begin
                        a_sorted[0] <= a[0]; a_sorted[1] <= a[1];
                        a_sorted[2] <= a[2]; a_sorted[3] <= a[3];
                        a_sorted[4] <= a[4]; a_sorted[5] <= a[5];
                        a_sorted[6] <= a[6]; a_sorted[7] <= a[7];
                        b_sorted[0] <= b[0]; b_sorted[1] <= b[1];
                        b_sorted[2] <= b[2]; b_sorted[3] <= b[3];
                        b_sorted[4] <= b[4]; b_sorted[5] <= b[5];
                        b_sorted[6] <= b[6]; b_sorted[7] <= b[7];
                        counter <= 4'd0;
                        if (n == 4'd0) begin
                            result <= 1'b1;
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            state <= SORT;
                        end
                    end
                end
                
                SORT: begin
                    // Bubble sort pass
                    if (j < n_reg - 4'd1) begin
                        if (b_sorted[j] > b_sorted[j + 4'd1]) begin
                            // Swap
                            temp_a <= a_sorted[j];
                            temp_b <= b_sorted[j];
                            a_sorted[j] <= a_sorted[j + 4'd1];
                            b_sorted[j] <= b_sorted[j + 4'd1];
                            a_sorted[j + 4'd1] <= temp_a;
                            b_sorted[j + 4'd1] <= temp_b;
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        sort_counter <= sort_counter + 4'd1;
                        if (sort_counter >= n_reg - 4'd1) begin
                            counter <= 4'd0;
                            current_time <= 16'd0;
                            valid <= 1'b1;
                            state <= PROCESS;
                        end
                    end
                end
                
                PROCESS: begin
                    if (counter < n_reg) begin
                        // Start time = max(current_time, a_sorted[counter])
                        if (current_time > a_sorted[counter]) begin
                            start_time <= current_time;
                        end else begin
                            start_time <= a_sorted[counter];
                        end
                        end_time <= b_sorted[counter];
                        
                        // Check if start_time + t <= end_time
                        if (start_time + t_reg <= b_sorted[counter]) begin
                            current_time <= start_time + t_reg;
                            counter <= counter + 4'd1;
                            valid <= valid;
                        end else begin
                            valid <= 1'b0;
                            state <= DONE;
                        end
                    end else begin
                        result <= valid;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule