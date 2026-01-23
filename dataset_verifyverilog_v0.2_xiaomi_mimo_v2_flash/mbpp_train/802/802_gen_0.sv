module rotation_counter (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input signed [15:0] arr [0:15],
    output reg [3:0] rotations,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_SORTED = 3'b001;
    localparam INIT_SEARCH = 3'b010;
    localparam COMPARE = 3'b011;
    localparam UPDATE_LEFT = 3'b100;
    localparam UPDATE_RIGHT = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Registers for binary search
    reg [3:0] left;
    reg [3:0] right;
    reg [3:0] mid;
    reg [3:0] next_left;
    reg [3:0] next_right;
    reg [3:0] next_rotations;
    
    // Storage for array elements
    reg signed [15:0] stored_arr [0:15];
    
    // Helper signals
    wire signed [15:0] arr_mid;
    wire signed [15:0] arr_right;
    wire signed [15:0] arr_0;
    wire signed [15:0] arr_n_minus_1;
    
    assign arr_mid = stored_arr[mid];
    assign arr_right = stored_arr[right];
    assign arr_0 = stored_arr[0];
    assign arr_n_minus_1 = stored_arr[n-1];

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            left <= 4'b0;
            right <= 4'b0;
            rotations <= 4'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            left <= next_left;
            right <= next_right;
            rotations <= next_rotations;
            // done is combinational, but we can register it for one-cycle pulse
            // Actually, let's make it combinational logic driven by state
        end
    end

    // Next state and output logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_left = left;
        next_right = right;
        next_rotations = rotations;
        done = 1'b0;

        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CHECK_SORTED;
                end
            end

            CHECK_SORTED: begin
                // Check if arr[0] <= arr[n-1]
                if (n == 4'd1) begin
                    // Single element case
                    next_state = DONE;
                    next_rotations = 4'd0;
                end else if (arr_0 <= arr_n_minus_1) begin
                    // Already sorted
                    next_state = DONE;
                    next_rotations = 4'd0;
                end else begin
                    // Need to find minimum
                    next_state = INIT_SEARCH;
                end
            end

            INIT_SEARCH: begin
                next_left = 4'd0;
                next_right = n - 1;
                next_state = COMPARE;
            end

            COMPARE: begin
                // while (left <= right)
                if (left <= right) begin
                    mid = (left + right) >> 1; // div by 2
                    
                    // Wait one cycle for array read? 
                    // In pure combinational logic based on current registers:
                    // The array values are combinational inputs to this block.
                    // To match the "loaded on start" requirement, we assume stored_arr is used.
                    // However, accessing stored_arr[mid] directly here requires index to be stable.
                    // Since mid is combinational here, it updates immediately when left/right change.
                    // We need to evaluate based on current state inputs.
                    
                    // To avoid multiple drivers for 'mid' and to ensure pipelining/
                    // synchronous behavior, we rely on the 'mid' register or re-evaluate.
                    // Let's re-evaluate mid specifically for this cycle's comparison.
                    mid = (left + right) >> 1;
                    
                    if (stored_arr[mid] > stored_arr[right]) begin
                        next_state = UPDATE_LEFT;
                    end else begin
                        next_state = UPDATE_RIGHT;
                    end
                end else begin
                    next_state = DONE;
                    next_rotations = left;
                end
            end

            UPDATE_LEFT: begin
                // left = mid + 1
                next_left = mid + 1;
                next_right = right;
                next_state = COMPARE;
            end

            UPDATE_RIGHT: begin
                // right = mid
                next_left = left;
                next_right = mid;
                next_state = COMPARE;
            end

            DONE: begin
                done = 1'b1;
                if (start) begin
                    next_state = CHECK_SORTED;
                    done = 1'b0; // Reset done if starting immediately
                end else begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Array loading logic
    // Since inputs are external, we capture them into internal storage on start
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset storage (optional, but good practice)
            // for (i = 0; i < 16; i = i + 1) stored_arr[i] <= 16'sd0;
        end else if (start && state == IDLE) begin
            // Load array when start is asserted in IDLE state
            for (i = 0; i < 16; i = i + 1) begin
                stored_arr[i] <= arr[i];
            end
        end
    end

endmodule