module pair_wise (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state, next_state;
    reg [2:0] pair_index;          // Counter for pair index (0 to 7)
    reg [7:0] arr_i;               // Storage for arr[i]
    reg [7:0] arr_i_plus_1;        // Storage for arr[i+1]
    reg [3:0] valid_len;           // Store len for processing
    reg [7:0] cycle_count;         // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && (len > 4'd1)) begin
                    next_state = PROCESS;
                end else if (start && (len <= 4'd1)) begin
                    next_state = DONE;
                end else begin
                    next_state = IDLE;
                end
            end
            PROCESS: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE;
                end else if (pair_index >= (valid_len - 4'd1)) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESS;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            pair_index <= 3'd0;
            arr_i <= 8'd0;
            arr_i_plus_1 <= 8'd0;
            valid_len <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    pair_index <= 3'd0;
                    cycle_count <= 8'd0;
                    
                    if (start && (len > 4'd1)) begin
                        valid_len <= len;
                        arr_i <= arr[0];
                        arr_i_plus_1 <= arr[1];
                        pair_index <= 3'd1;
                        cycle_count <= 8'd1;
                    end else if (start && (len <= 4'd1)) begin
                        valid_len <= len;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Output current pair
                    result <= {arr_i_plus_1, arr_i};
                    done <= 1'b1;
                    
                    // Load next pair for next cycle
                    if (pair_index < valid_len) begin
                        arr_i <= arr_i_plus_1;
                        arr_i_plus_1 <= arr[pair_index + 3'd1];
                        pair_index <= pair_index + 3'd1;
                    end
                end
                
                DONE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    pair_index <= 3'd0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule