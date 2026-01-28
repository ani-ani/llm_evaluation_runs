module dinner_seating(
    input clk,
    input rst_n,
    input start,
    input [31:0] l_in,
    input [31:0] r_in,
    input load_en,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Constants
    localparam [3:0] N = 4'd16;
    localparam [12:0] MAX_CYCLES = 13'd5000;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] guest_count;
    reg [12:0] cycle_count;
    reg [31:0] l_array [0:15];
    reg [31:0] r_array [0:15];
    reg [31:0] sum;
    reg [4:0] i, j;
    reg [31:0] temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            guest_count <= 4'd0;
            cycle_count <= 13'd0;
            sum <= 32'd0;
            i <= 5'd0;
            j <= 5'd0;
            done <= 1'b0;
            ready <= 1'b1;
            result <= 32'd0;

            // Initialize arrays
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                l_array[k] <= 32'd0;
                r_array[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                    ready = 1'b0;
                end
            end

            LOAD: begin
                if (load_en) begin
                    if (guest_count == N - 1) begin
                        next_state = SORT;
                    end
                end
            end

            SORT: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                if (i == N) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            guest_count <= 4'd0;
        end else begin
            if (state == LOAD && load_en) begin
                l_array[guest_count] <= l_in;
                r_array[guest_count] <= r_in;
                guest_count <= guest_count + 4'd1;
            end
        end
    end

    // Sorting logic (bubble sort)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 5'd0;
            j <= 5'd0;
            cycle_count <= 13'd0;
        end else begin
            if (state == SORT) begin
                cycle_count <= cycle_count + 13'd1;

                // Bubble sort for l_array
                if (i < N - 1) begin
                    if (j < N - i - 1) begin
                        if (l_array[j] > l_array[j + 1]) begin
                            temp <= l_array[j];
                            l_array[j] <= l_array[j + 1];
                            l_array[j + 1] <= temp;
                        end
                        j <= j + 5'd1;
                    end else begin
                        j <= 5'd0;
                        i <= i + 5'd1;
                    end
                end else begin
                    i <= 5'd0;
                    j <= 5'd0;
                    next_state = COMPUTE;
                end
            end
        end
    end

    // Compute sum
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= 32'd0;
            i <= 5'd0;
        end else begin
            if (state == COMPUTE) begin
                if (i < N) begin
                    if (l_array[i] > r_array[i]) begin
                        sum <= sum + l_array[i] + 32'd1;
                    end else begin
                        sum <= sum + r_array[i] + 32'd1;
                    end
                    i <= i + 5'd1;
                end else begin
                    result <= sum;
                    next_state = FINISH;
                end
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == FINISH) begin
                done <= 1'b1;
                ready <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Ready signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
        end else begin
            if (state == IDLE) begin
                ready <= 1'b1;
            end else begin
                ready <= 1'b0;
            end
        end
    end

endmodule