module ArrayPartitioner(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:7],
    input wire [3:0] len,
    output reg signed [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] current_index;
    reg [3:0] swap_index;
    reg signed [7:0] working_array [0:7];
    reg swap_pending;
    reg swap_done;

    // Initialize working array
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_index <= 4'd0;
            swap_index <= 4'd0;
            swap_pending <= 1'b0;
            swap_done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                working_array[i] <= 8'd0;
            end
        end else begin
            // Initialize working array on start
            if (state == IDLE && start) begin
                for (i = 0; i < 8; i = i + 1) begin
                    working_array[i] <= arr[i];
                end
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
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
                    next_state = PROCESSING;
                end
            end
            PROCESSING: begin
                if (swap_done || cycle_count >= 8'd100) begin
                    next_state = COMPLETE;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
            current_index <= 4'd0;
            swap_index <= 4'd0;
            swap_pending <= 1'b0;
            swap_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    current_index <= 4'd0;
                    swap_index <= 4'd0;
                    swap_pending <= 1'b0;
                    swap_done <= 1'b0;
                end
                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Find next negative element to swap
                    if (!swap_pending) begin
                        swap_pending <= 1'b1;
                        swap_index <= current_index;
                        current_index <= current_index + 4'd1;
                    end
                    
                    // Perform swap if needed
                    if (swap_pending && swap_index < len && current_index < len) begin
                        if (working_array[swap_index] >= 8'd0 && working_array[current_index] < 8'd0) begin
                            // Swap elements
                            working_array[swap_index] <= working_array[current_index];
                            working_array[current_index] <= working_array[swap_index];
                            swap_pending <= 1'b0;
                        end else if (working_array[swap_index] < 8'd0) begin
                            swap_index <= swap_index + 4'd1;
                        end
                        
                        // Check if we've processed all elements
                        if (swap_index >= len - 1 && current_index >= len - 1) begin
                            swap_done <= 1'b1;
                        end
                    end
                end
                COMPLETE: begin
                    // Output results
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= working_array[i];
                    end
                    done <= 1'b1;
                end
                default: begin
                    cycle_count <= 8'd0;
                    current_index <= 4'd0;
                    swap_index <= 4'd0;
                    swap_pending <= 1'b0;
                    swap_done <= 1'b0;
                end
            endcase
        end
    end

    // Done signal handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == COMPLETE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule