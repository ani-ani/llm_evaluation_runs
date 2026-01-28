module k_multiple_free_set(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] k,
    input wire [15:0] arr [0:15],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] BUILD     = 3'd3;
    localparam [2:0] CALCULATE = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;

    // Internal registers for data
    reg [15:0] arr_reg [0:15];
    reg [15:0] sorted_arr [0:15];
    reg [15:0] k_reg;
    reg [3:0] n_reg;

    // Graph representation: conflict matrix
    reg conflict [0:15][0:15];
    reg excluded [0:15];

    // Sorting variables
    reg [3:0] i, j;
    reg [15:0] temp;

    // Calculation variables
    reg [3:0] idx;
    reg [7:0] count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            
            // Reset arrays
            for (i = 0; i < 16; i = i + 1) begin
                arr_reg[i] <= 16'd0;
                sorted_arr[i] <= 16'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    conflict[i][j] <= 1'b0;
                end
                excluded[i] <= 1'b0;
            end
            
            i <= 4'd0;
            j <= 4'd0;
            idx <= 4'd0;
            count <= 8'd0;
            k_reg <= 16'd0;
            n_reg <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load inputs
                    n_reg <= n;
                    k_reg <= k;
                    for (i = 0; i < 16; i = i + 1) begin
                        arr_reg[i] <= arr[i];
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort implementation
                    if (i < n_reg - 1) begin
                        if (j < n_reg - i - 1) begin
                            if (arr_reg[j] > arr_reg[j + 1]) begin
                                temp <= arr_reg[j];
                                arr_reg[j] <= arr_reg[j + 1];
                                arr_reg[j + 1] <= temp;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        // Copy to sorted_arr
                        for (i = 0; i < 16; i = i + 1) begin
                            sorted_arr[i] <= arr_reg[i];
                        end
                        i <= 4'd0;
                        j <= 4'd0;
                        next_state <= BUILD;
                    end
                end

                BUILD: begin
                    // Build conflict matrix
                    if (i < n_reg) begin
                        if (j < n_reg) begin
                            if (i != j && sorted_arr[j] != 16'd0 && sorted_arr[i] != 16'd0) begin
                                if (sorted_arr[i] * k_reg == sorted_arr[j] || sorted_arr[j] * k_reg == sorted_arr[i]) begin
                                    conflict[i][j] <= 1'b1;
                                    conflict[j][i] <= 1'b1;
                                end
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        next_state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    // Greedy selection from largest to smallest
                    if (idx < n_reg) begin
                        if (!excluded[idx]) begin
                            count <= count + 8'd1;
                            // Mark the k-multiple as excluded
                            for (i = 0; i < n_reg; i = i + 1) begin
                                if (sorted_arr[i] * k_reg == sorted_arr[idx]) begin
                                    excluded[i] <= 1'b1;
                                end
                            end
                        end
                        idx <= idx + 1;
                    end else begin
                        result <= count;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter for safety
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            end
        end
    end

endmodule