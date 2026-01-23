module group_photo_area (
    input clk, rst_n, start,
    input [2:0] n,                   // number of friends (1-8)
    input [9:0] max_h,               // candidate max height
    // Friend dimensions (10 bits each)
    input [9:0] w0, h0, w1, h1, w2, h2, w3, h3,
    input [9:0] w4, h4, w5, h5, w6, h6, w7, h7,
    output reg [23:0] area,          // computed area (total_width * max_h)
    output reg done                  // computation finished
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] STEP1 = 3'd1;  // Process friends
localparam [2:0] STEP2 = 3'd2;  // Sort by (h-w)
localparam [2:0] STEP3 = 3'd3;  // Calculate total width
localparam [2:0] DONE  = 3'd4;
localparam [2:0] ERROR = 3'd5;

// Registers
reg [2:0] state;
reg [2:0] i;               // Friend index
reg [2:0] k;               // Remaining lies
reg [9:0] w_arr [0:7];      // Width array
reg [9:0] h_arr [0:7];      // Height array
reg [12:0] total_width;    // Accumulated width (max 8000)
reg [2:0] sort_pass;       // Bubble sort pass counter
reg [2:0] sort_idx;        // Bubble sort index

// Combinational helpers
wire signed [10:0] diff0 = h_arr[sort_idx] - w_arr[sort_idx];
wire signed [10:0] diff1 = h_arr[sort_idx + 1] - w_arr[sort_idx + 1];

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        area <= 24'd0;
        k <= 3'd0;
        total_width <= 13'd0;
        sort_pass <= 3'd0;
        sort_idx <= 3'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    k <= n >> 1; // Initialize lies count
                    i <= 3'd0;
                    state <= STEP1;
                end
            end

            STEP1: begin  // Process each friend
                // Get current friend's dimensions
                case (i)
                    3'd0: begin w_arr[0] <= w0; h_arr[0] <= h0; end
                    3'd1: begin w_arr[1] <= w1; h_arr[1] <= h1; end
                    3'd2: begin w_arr[2] <= w2; h_arr[2] <= h2; end
                    3'd3: begin w_arr[3] <= w3; h_arr[3] <= h3; end
                    3'd4: begin w_arr[4] <= w4; h_arr[4] <= h4; end
                    3'd5: begin w_arr[5] <= w5; h_arr[5] <= h5; end
                    3'd6: begin w_arr[6] <= w6; h_arr[6] <= h6; end
                    3'd7: begin w_arr[7] <= w7; h_arr[7] <= h7; end
                endcase

                // Force lie if height > max_h
                if (h_arr[i] > max_h) begin
                    if (k > 3'd0 && w_arr[i] <= max_h) begin
                        // Swap dimensions
                        w_arr[i] <= h_arr[i];
                        h_arr[i] <= w_arr[i];
                        k <= k - 3'd1;
                    end else begin
                        state <= ERROR;
                    end
                end

                if (i == 3'd7) begin
                    sort_pass <= 3'd0;
                    sort_idx <= 3'd0;
                    state <= STEP2;
                end else begin
                    i <= i + 3'd1;
                end
            end

            STEP2: begin  // Bubble sort by (h-w) increasing
                if (diff0 > diff1) begin  // Swap if out of order
                    w_arr[sort_idx] <= w_arr[sort_idx + 1];
                    w_arr[sort_idx + 1] <= w_arr[sort_idx];
                    h_arr[sort_idx] <= h_arr[sort_idx + 1];
                    h_arr[sort_idx + 1] <= h_arr[sort_idx];
                end
                sort_idx <= sort_idx + 3'd1;
                if (sort_idx >= 3'd6) begin  // End of pass
                    sort_idx <= 3'd0;
                    sort_pass <= sort_pass + 3'd1;
                    if (sort_pass >= 3'd6) begin  // 7 passes for 8 elements
                        total_width <= 13'd0;
                        i <= 3'd0;
                        state <= STEP3;
                    end
                end
            end

            STEP3: begin  // Calculate total width
                if (i < 3'd8) begin
                    // Lie if allowed and reduces width
                    if (k > 3'd0 && w_arr[i] <= max_h && h_arr[i] < w_arr[i]) begin
                        total_width <= total_width + h_arr[i];
                        k <= k - 3'd1;
                    end else begin
                        total_width <= total_width + w_arr[i];
                    end
                    i <= i + 3'd1;
                end else begin
                    // Compute area (width * height)
                    area <= total_width * max_h;
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1'b1;
                if (!start) state <= IDLE;
            end

            ERROR: begin
                area <= 24'hFFFFFF;  // Large error value
                state <= DONE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule