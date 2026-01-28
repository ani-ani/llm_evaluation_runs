module phone_network_detector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N_in,
    input wire [31:0] M_in,
    input wire [31:0] P_i [0:255],
    input wire [31:0] C_i [0:255],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] FIND_MAX  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Internal arrays for positions and counts
    reg [31:0] P_sorted [0:255];
    reg [31:0] C_sorted [0:255];
    reg [31:0] P_temp [0:255];
    reg [31:0] C_temp [0:255];

    // Sorting variables
    reg [7:0] i, j;
    reg [31:0] temp_P, temp_C;

    // Maximum finding variables
    reg [31:0] current_max;
    reg [7:0] max_index;

    // Initialize arrays
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all arrays
            for (k = 0; k < 256; k = k + 1) begin
                P_sorted[k] <= 32'd0;
                C_sorted[k] <= 32'd0;
                P_temp[k] <= 32'd0;
                C_temp[k] <= 32'd0;
            end
            
            i <= 8'd0;
            j <= 8'd0;
            temp_P <= 32'd0;
            temp_C <= 32'd0;
            current_max <= 32'd0;
            max_index <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
        end else begin
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
                    // Copy input arrays to internal arrays
                    for (k = 0; k < 256; k = k + 1) begin
                        if (k < N_in) begin
                            P_temp[k] <= P_i[k];
                            C_temp[k] <= C_i[k];
                        end else begin
                            P_temp[k] <= 32'd0;
                            C_temp[k] <= 32'd0;
                        end
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort implementation
                    if (j < N_in - 1) begin
                        if (i < N_in - j - 1) begin
                            // Compare and swap
                            if (P_temp[i] > P_temp[i + 1]) begin
                                temp_P <= P_temp[i];
                                temp_C <= C_temp[i];
                                P_temp[i] <= P_temp[i + 1];
                                C_temp[i] <= C_temp[i + 1];
                                P_temp[i + 1] <= temp_P;
                                C_temp[i + 1] <= temp_C;
                            end
                            i <= i + 1;
                        end else begin
                            i <= 8'd0;
                            j <= j + 1;
                        end
                    end else begin
                        // Copy sorted arrays
                        for (k = 0; k < 256; k = k + 1) begin
                            P_sorted[k] <= P_temp[k];
                            C_sorted[k] <= C_temp[k];
                        end
                        next_state <= FIND_MAX;
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                FIND_MAX: begin
                    // Find maximum C_i in sorted array
                    if (max_index < N_in) begin
                        if (C_sorted[max_index] > current_max) begin
                            current_max <= C_sorted[max_index];
                        end
                        max_index <= max_index + 1;
                    end else begin
                        result <= current_max;
                        next_state <= DONE_STATE;
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule