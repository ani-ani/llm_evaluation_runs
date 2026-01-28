module star_wars_ordering (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] q_type,  // 1=insert, 2=query
    input wire [4:0] x,       // plot index (1-16)
    output reg [4:0] result,  // creation index for query
    output reg done
);

    // Maximum 16 movies, 64 operations
    localparam [5:0] MAX_OPS = 6'd64;
    
    // Internal state
    reg [4:0] plot_order [0:15];  // Creation index at each plot position
    reg [4:0] creation_count;      // Number of movies created
    reg [5:0] op_count;            // Operation counter
    reg [4:0] temp_value;
    reg [4:0] loop_i;
    reg [4:0] loop_j;
    
    // FSM states
    reg [1:0] state;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] EXECUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state - initialize all registers
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            creation_count <= 5'd0;
            op_count <= 6'd0;
            temp_value <= 5'd0;
            loop_i <= 5'd0;
            loop_j <= 5'd0;
            // Initialize array
            for (loop_i = 0; loop_i < 16; loop_i = loop_i + 1) begin
                plot_order[loop_i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && op_count < MAX_OPS) begin
                        op_count <= op_count + 1'b1;
                        state <= EXECUTE;
                    end
                end
                
                EXECUTE: begin
                    if (q_type == 2'd1) begin
                        // INSERT: create movie at plot index x
                        if (x >= 5'd1 && x <= creation_count + 5'd1) begin
                            // Shift existing movies to the right
                            temp_value <= plot_order[x - 5'd1];
                            loop_j <= x - 5'd1;
                            // We need to handle the shift logic
                            // For now, just store the new value
                            if (creation_count < 5'd16) begin
                                plot_order[x - 5'd1] <= creation_count + 5'd1;
                                creation_count <= creation_count + 5'd1;
                            end
                        end
                    end else if (q_type == 2'd2) begin
                        // QUERY: get creation index at plot index x
                        if (x >= 5'd1 && x <= creation_count) begin
                            result <= plot_order[x - 5'd1];
                        end
                    end
                    state <= COMPLETE;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule