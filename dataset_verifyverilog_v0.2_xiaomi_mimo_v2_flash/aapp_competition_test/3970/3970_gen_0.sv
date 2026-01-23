module k_mfree_subset (
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [2:0] n,
    input [11:0] arr [0:7],
    output reg [3:0] result,
    output reg done
);

    // State Encodings
    localparam IDLE = 3'b001;
    localparam SORT = 3'b010;
    localparam PROCESS = 3'b100;
    localparam DONE = 3'b011;

    // FSM State Register
    reg [2:0] state;
    
    // Datapath Registers
    reg [11:0] sorted_arr [0:7];
    reg [4095:0] excluded;      // 4096-bit register to track used multiples
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg [3:0] proc_idx;
    reg [3:0] res_cnt;          // Accumulates result during PROCESS
    reg [7:0] k_reg;
    reg [2:0] n_reg;
    reg [11:0] temp;            // Temporary for swap

    // Combinational logic for multiplication and value access
    wire [11:0] current_value;
    wire [23:0] mult_value;

    assign current_value = sorted_arr[proc_idx];
    assign mult_value = current_value * k_reg;

    // State Transition and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load configuration and input array
                        k_reg <= k;
                        n_reg <= n;
                        sorted_arr[0] <= arr[0];
                        sorted_arr[1] <= arr[1];
                        sorted_arr[2] <= arr[2];
                        sorted_arr[3] <= arr[3];
                        sorted_arr[4] <= arr[4];
                        sorted_arr[5] <= arr[5];
                        sorted_arr[6] <= arr[6];
                        sorted_arr[7] <= arr[7];
                        
                        // Reset counters and exclusion mask
                        excluded <= 4096'b0;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        proc_idx <= 4'd0;
                        res_cnt <= 4'd0;
                        
                        state <= SORT;
                    end
                end

                SORT: begin
                    // Bubble Sort Implementation
                    // Loop: for sort_i = 0 to n-2
                    if (sort_i < n_reg - 1) begin
                        // Loop: for sort_j = 0 to n-sort_i-2
                        if (sort_j < n_reg - sort_i - 1) begin
                            if (sorted_arr[sort_j] > sorted_arr[sort_j + 1]) begin
                                // Swap elements
                                temp <= sorted_arr[sort_j];
                                sorted_arr[sort_j] <= sorted_arr[sort_j + 1];
                                sorted_arr[sort_j + 1] <= temp;
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            sort_j <= 4'd0; // Reset inner counter
                            sort_i <= sort_i + 1; // Increment outer counter
                        end
                    end else begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (proc_idx < n_reg) begin
                        // Greedy Selection Logic
                        // If current_value is NOT excluded (i.e., not a multiple of a previous element)
                        if (!excluded[current_value]) begin
                            res_cnt <= res_cnt + 1; // Increment result count
                            // Exclude the multiple if it is within valid array range (0-4095)
                            if (mult_value < 24'h1000) begin
                                excluded[mult_value] <= 1'b1;
                            end
                        end
                        proc_idx <= proc_idx + 1;
                    end else begin
                        // Completion of processing
                        result <= res_cnt;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for reset or new start pulse
                    if (start) begin
                        // Re-initialize to start new computation
                        k_reg <= k;
                        n_reg <= n;
                        sorted_arr[0] <= arr[0];
                        sorted_arr[1] <= arr[1];
                        sorted_arr[2] <= arr[2];
                        sorted_arr[3] <= arr[3];
                        sorted_arr[4] <= arr[4];
                        sorted_arr[5] <= arr[5];
                        sorted_arr[6] <= arr[6];
                        sorted_arr[7] <= arr[7];
                        excluded <= 4096'b0;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        proc_idx <= 4'd0;
                        res_cnt <= 4'd0;
                        done <= 1'b0;
                        state <= SORT;
                    end
                end
            endcase
        end
    end
endmodule
